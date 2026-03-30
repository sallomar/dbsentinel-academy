-- ============================================================================
-- SCRIPT     : v_redo_checkpoint.sql
-- MODULE     : M1.5 - Processus Background Oracle
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_redo_checkpoint.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF
SET DEFINE OFF

PROMPT
PROMPT ==================== LGWR / CKPT - ACTIVITE REDO & CHECKPOINT ====================
PROMPT

-- -----------------------------------------------
-- 1. Statut des groupes redo log
-- -----------------------------------------------

COL group_num    FORMAT 999    HEAD "Grp"
COL sequence_num FORMAT 99999  HEAD "Seq#"
COL taille_mo    FORMAT 999    HEAD "Mo"
COL grp_status   FORMAT A10    HEAD "Statut"
COL archived     FORMAT A3     HEAD "Arc"
COL members      FORMAT 99     HEAD "Mbr"

SELECT l.group#                                                 AS group_num
      ,l.sequence#                                              AS sequence_num
      ,l.bytes / 1048576                                        AS taille_mo
      ,l.status                                                 AS grp_status
      ,l.archived                                               AS archived
      ,l.members                                                AS members
  FROM v$log l
 ORDER BY l.group#
;

PROMPT
PROMPT  Activite redo (LGWR) :
PROMPT

-- -----------------------------------------------
-- 2. Statistiques redo / LGWR
-- -----------------------------------------------

COL metrique FORMAT A40  HEAD "Metrique LGWR"
COL valeur   FORMAT A20  HEAD "Valeur"

SELECT name                                                     AS metrique
      ,CASE WHEN value >= 1048576
            THEN LPAD(TRIM(TO_CHAR(value/1048576, '999,999')) || ' MB', 15)
            ELSE LPAD(TRIM(TO_CHAR(value, '999,999,999')), 15)
       END                                                      AS valeur
  FROM v$sysstat
 WHERE name IN (
    'redo size'
   ,'redo writes'
   ,'redo blocks written'
   ,'redo write time'
   ,'redo log space requests'
 )
 ORDER BY CASE name
    WHEN 'redo size'                THEN 1
    WHEN 'redo writes'              THEN 2
    WHEN 'redo blocks written'      THEN 3
    WHEN 'redo write time'          THEN 4
    WHEN 'redo log space requests'  THEN 5
 END
;

PROMPT
PROMPT  Attentes LGWR (log file sync = lenteur COMMIT) :
PROMPT

-- -----------------------------------------------
-- 3. Waits lies a LGWR et checkpoint
-- -----------------------------------------------

COL evenement   FORMAT A35  HEAD "Evenement"
COL total_waits FORMAT A15  HEAD "Total Waits"
COL time_waited FORMAT A15  HEAD "Temps (sec)"
COL avg_wait_ms FORMAT A12  HEAD "Moy (ms)"

SELECT e.event                                                  AS evenement
      ,LPAD(TRIM(TO_CHAR(e.total_waits, '999,999,999')), 13)   AS total_waits
      ,LPAD(TRIM(TO_CHAR(e.time_waited_micro/1000000, '999,999.9')), 12) AS time_waited
      ,LPAD(TRIM(TO_CHAR(
          CASE WHEN e.total_waits > 0
               THEN e.time_waited_micro / e.total_waits / 1000
               ELSE 0
          END, '990.99')), 10)                                  AS avg_wait_ms
  FROM v$system_event e
 WHERE e.event IN (
    'log file sync'
   ,'log file parallel write'
   ,'log buffer space'
   ,'log file switch completion'
   ,'checkpoint completed'
 )
 ORDER BY e.time_waited_micro DESC
;

PROMPT
PROMPT  Statut checkpoint :
PROMPT

-- -----------------------------------------------
-- 4. Checkpoint : coherence SGA / disque
-- -----------------------------------------------

COL element    FORMAT A40  HEAD "Element"
COL valeur_chk FORMAT A25  HEAD "Valeur"

SELECT 'Checkpoint SCN (V$DATABASE)'                            AS element
      ,TRIM(TO_CHAR(checkpoint_change#, '999,999,999,999'))     AS valeur_chk
  FROM v$database
UNION ALL
SELECT 'Dernier checkpoint (min datafile)'
      ,TO_CHAR(MIN(checkpoint_time), 'DD/MM/YYYY HH24:MI:SS')
  FROM v$datafile_header
UNION ALL
SELECT 'Log switches depuis startup'
      ,TRIM(TO_CHAR(COUNT(*), '999,999'))
  FROM v$log_history
 WHERE first_time >= (SELECT startup_time FROM v$instance)
;

PROMPT
PROMPT  Actions :
PROMPT  log file sync > 10 ms moy     --> I/O disque lent ou redo trop petit
PROMPT  log buffer space > 0          --> Redo log buffer trop petit
PROMPT  log file switch completion    --> Redo logs trop petits, augmenter taille
PROMPT  checkpoint not complete       --> Augmenter taille ou nombre de redo logs
PROMPT
PROMPT ========================================================================

SET DEFINE ON
SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_5
