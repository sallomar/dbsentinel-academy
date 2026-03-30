-- ============================================================================
-- SCRIPT     : v_archive_monitor.sql
-- MODULE     : M1.5 - Processus Background Oracle
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_archive_monitor.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== ARCn - MONITORING ARCHIVAGE ====================
PROMPT

-- -----------------------------------------------
-- 1. Mode archivage et processus ARCn
-- -----------------------------------------------

COL information FORMAT A35  HEAD "Information"
COL valeur      FORMAT A45  HEAD "Valeur"

SELECT 'Mode archivage (LOG_MODE)'                              AS information
      ,log_mode                                                 AS valeur
  FROM v$database
UNION ALL
SELECT 'Role base (DATABASE_ROLE)'
      ,database_role
  FROM v$database
UNION ALL
SELECT 'Processus ARCn actifs'
      ,TRIM(TO_CHAR(COUNT(*), '999'))
  FROM v$bgprocess
 WHERE name LIKE 'ARC%' AND paddr != '00'
UNION ALL
SELECT 'Sequence redo courante'
      ,TRIM(TO_CHAR(sequence#, '999,999'))
  FROM v$log
 WHERE status = 'CURRENT'
;

PROMPT
PROMPT  Destinations d'archivage :
PROMPT

-- -----------------------------------------------
-- 2. Destinations archive et statut
-- -----------------------------------------------

COL dest_name FORMAT A25  HEAD "Destination"
COL statut    FORMAT A10  HEAD "Statut"
COL dest_path FORMAT A55  HEAD "Chemin"
COL err_msg   FORMAT A30  HEAD "Erreur"

SELECT dest_name                                                AS dest_name
      ,status                                                   AS statut
      ,destination                                              AS dest_path
      ,error                                                    AS err_msg
  FROM v$archive_dest
 WHERE status != 'INACTIVE'
   AND destination IS NOT NULL
 ORDER BY dest_id
;

PROMPT
PROMPT  Historique archivage recent (24h) :
PROMPT

-- -----------------------------------------------
-- 3. Archives generees derniere 24h
-- -----------------------------------------------

COL sequence_num FORMAT 999,999  HEAD "Sequence"
COL taille_mo    FORMAT 999      HEAD "Mo"
COL heure        FORMAT A17      HEAD "Date/Heure"

SELECT sequence#                                                AS sequence_num
      ,blocks * block_size / 1048576                            AS taille_mo
      ,TO_CHAR(completion_time, 'DD/MM HH24:MI:SS')             AS heure
  FROM v$archived_log
 WHERE completion_time >= SYSDATE - 1
   AND standby_dest = 'NO'
 ORDER BY sequence# DESC
 FETCH FIRST 15 ROWS ONLY
;

PROMPT
PROMPT  Rythme d'archivage (log switches) :
PROMPT

-- -----------------------------------------------
-- 4. Frequence log switches (1h vs 24h)
-- -----------------------------------------------

COL periode   FORMAT A25  HEAD "Periode"
COL nb_switch FORMAT A10  HEAD "Switches"
COL avg_min   FORMAT A15  HEAD "Moy (min)"

SELECT 'Derniere heure'                                         AS periode
      ,LPAD(TRIM(TO_CHAR(COUNT(*), '999')), 8)                  AS nb_switch
      ,LPAD(TRIM(TO_CHAR(
          CASE WHEN COUNT(*) > 1
               THEN 60 / COUNT(*)
               ELSE NULL
          END, '990.0')), 12)                                   AS avg_min
  FROM v$log_history
 WHERE first_time >= SYSDATE - 1/24
UNION ALL
SELECT 'Dernieres 24 heures'
      ,LPAD(TRIM(TO_CHAR(COUNT(*), '999')), 8)
      ,LPAD(TRIM(TO_CHAR(
          CASE WHEN COUNT(*) > 1
               THEN 1440 / COUNT(*)
               ELSE NULL
          END, '990.0')), 12)
  FROM v$log_history
 WHERE first_time >= SYSDATE - 1
;

PROMPT
PROMPT  Actions :
PROMPT  NOARCHIVELOG en prod          --> DANGEREUX : pas de recovery PITR possible
PROMPT  Destination ERROR             --> Verifier espace disque et permissions
PROMPT  > 6 switches/heure           --> Redo logs trop petits, augmenter taille
PROMPT  ORA-00257                    --> Destination pleine, liberer espace URGENT
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_5
