-- ============================================================================
-- SCRIPT     : v_incarnation_history.sql
-- MODULE     : M1.8 - Control Files
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_incarnation_history.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== INCARNATIONS - HISTORIQUE RESETLOGS ====================
PROMPT

-- -----------------------------------------------
-- 1. Etat actuel SCN et RESETLOGS
-- -----------------------------------------------

COL information FORMAT A45  HEAD "Information"
COL valeur      FORMAT A45  HEAD "Valeur"

SELECT 'DBID (identifiant unique)'                               AS information
      ,TRIM(TO_CHAR(dbid))                                       AS valeur
  FROM v$database
UNION ALL
SELECT 'Checkpoint SCN courant'
      ,TRIM(TO_CHAR(checkpoint_change#, '999,999,999,999'))
  FROM v$database
UNION ALL
SELECT 'Dernier RESETLOGS SCN'
      ,TRIM(TO_CHAR(resetlogs_change#, '999,999,999,999'))
  FROM v$database
UNION ALL
SELECT 'Dernier RESETLOGS - Date'
      ,TO_CHAR(resetlogs_time, 'DD/MM/YYYY HH24:MI:SS')
  FROM v$database
UNION ALL
SELECT 'Temps depuis dernier RESETLOGS'
      ,TRIM(TO_CHAR(ROUND(SYSDATE - resetlogs_time, 1)))
       || ' jours ('
       || TRIM(TO_CHAR(ROUND((SYSDATE - resetlogs_time)/365, 1)))
       || ' annees)'
  FROM v$database
UNION ALL
SELECT 'Sequence Control File'
      ,TRIM(TO_CHAR(controlfile_sequence#, '999,999,999'))
  FROM v$database
;

PROMPT
PROMPT  Toutes les incarnations enregistrees :
PROMPT

-- -----------------------------------------------
-- 2. Historique complet incarnations
-- -----------------------------------------------

COL incarnation FORMAT 9999  HEAD "Inc#"
COL inc_status  FORMAT A10   HEAD "Statut"
COL parent_inc  FORMAT 9999  HEAD "Parent"
COL scn_debut   FORMAT A18   HEAD "SCN debut"
COL date_reset  FORMAT A20   HEAD "Date Reset"
COL flashback   FORMAT A10   HEAD "Flashback"

SELECT incarnation#                                              AS incarnation
      ,status                                                    AS inc_status
      ,prior_incarnation#                                        AS parent_inc
      ,LPAD(TRIM(TO_CHAR(resetlogs_change#, '999,999,999,999')), 16) AS scn_debut
      ,TO_CHAR(resetlogs_time, 'DD/MM/YYYY HH24:MI:SS')          AS date_reset
      ,flashback_database_allowed                                AS flashback
  FROM v$database_incarnation
 ORDER BY incarnation#
;

PROMPT
PROMPT  Recovery window theorique :
PROMPT

-- -----------------------------------------------
-- 3. Fenetre PITR theorique
-- -----------------------------------------------

COL metrique     FORMAT A45  HEAD "Metrique"
COL valeur_calc  FORMAT A50  HEAD "Valeur"

SELECT 'Nombre d''incarnations'                                  AS metrique
      ,TRIM(TO_CHAR(COUNT(*), '999')) || ' incarnation(s)'       AS valeur_calc
  FROM v$database_incarnation
UNION ALL
SELECT 'Plus ancien archive log disponible'
      ,NVL(TO_CHAR(MIN(first_time), 'DD/MM/YYYY HH24:MI:SS'),
           'Aucun archive log disponible')
  FROM v$archived_log
 WHERE deleted = 'NO'
UNION ALL
SELECT 'Plus recent archive log disponible'
      ,NVL(TO_CHAR(MAX(first_time), 'DD/MM/YYYY HH24:MI:SS'),
           'Aucun archive log disponible')
  FROM v$archived_log
 WHERE deleted = 'NO'
UNION ALL
SELECT 'Fenetre PITR theorique (archives disponibles)'
      ,CASE WHEN COUNT(*) > 0
            THEN TRIM(TO_CHAR(ROUND(MAX(first_time) - MIN(first_time), 1)))
                 || ' jours de recovery possible'
            ELSE 'Aucune fenetre PITR (mode NOARCHIVELOG ou archives purgees)'
       END
  FROM v$archived_log
 WHERE deleted = 'NO'
;

PROMPT
PROMPT  Inc# CURRENT          --> Incarnation active
PROMPT  Inc# PARENT/ORPHAN    --> Anciennes incarnations (apres RESETLOGS)
PROMPT  Plusieurs incarnations --> Recovery passes, normal en cas de PITR
PROMPT  RESETLOGS recent       --> Verifier raison (recovery incomplet ?)
PROMPT  Note : DBID inchange entre incarnations de la meme base
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_8
