-- ============================================================================
-- SCRIPT     : check_redo_config.sql
-- MODULE     : M1.7 - Online Redo Logs et Archivelog
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @check_redo_config.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== REDO LOGS - CONFIGURATION COMPLETE ====================
PROMPT

-- -----------------------------------------------
-- 1. Configuration generale redo / archivage
-- -----------------------------------------------

COL information FORMAT A40  HEAD "Configuration"
COL valeur      FORMAT A45  HEAD "Valeur"

SELECT 'Mode archivage'                                          AS information
      ,log_mode                                                  AS valeur
  FROM v$database
UNION ALL
SELECT 'Force Logging'
      ,force_logging
  FROM v$database
UNION ALL
SELECT 'Role base'
      ,database_role
  FROM v$database
UNION ALL
SELECT 'Nombre de groupes redo'
      ,TRIM(TO_CHAR(COUNT(DISTINCT group#), '999'))
  FROM v$log
UNION ALL
SELECT 'Taille par groupe'
      ,TRIM(TO_CHAR(MIN(bytes)/1048576, '999')) || ' MB'
       || CASE WHEN MIN(bytes) != MAX(bytes)
               THEN ' (non uniforme : min=' || TRIM(TO_CHAR(MIN(bytes)/1048576,'999'))
                    || ' max=' || TRIM(TO_CHAR(MAX(bytes)/1048576,'999')) || ')'
               ELSE ' (uniforme)' END
  FROM v$log
UNION ALL
SELECT 'Espace redo total'
      ,TRIM(TO_CHAR(SUM(bytes)/1048576, '999,999')) || ' MB'
  FROM v$log
;

PROMPT
PROMPT  Statut des groupes redo :
PROMPT

-- -----------------------------------------------
-- 2. Statut de chaque groupe redo
-- -----------------------------------------------

COL grp      FORMAT 999    HEAD "Grp"
COL seq      FORMAT 99999  HEAD "Seq#"
COL taille   FORMAT A8     HEAD "Mo"
COL statut   FORMAT A10    HEAD "Statut"
COL archived FORMAT A4     HEAD "Arc"
COL membres  FORMAT 99     HEAD "Mbr"

SELECT l.group#                                                  AS grp
      ,l.sequence#                                               AS seq
      ,LPAD(TRIM(TO_CHAR(l.bytes/1048576, '999')), 6)           AS taille
      ,l.status                                                  AS statut
      ,l.archived                                                AS archived
      ,l.members                                                 AS membres
  FROM v$log l
 ORDER BY l.group#
;

PROMPT
PROMPT  Verification securite :
PROMPT

-- -----------------------------------------------
-- 3. Alertes de configuration
-- -----------------------------------------------

COL element   FORMAT A40  HEAD "Verification"
COL resultat  FORMAT A50  HEAD "Resultat"

SELECT 'Mode archivage'                                          AS element
      ,CASE WHEN log_mode = 'ARCHIVELOG'
            THEN 'OK (ARCHIVELOG)'
            ELSE '!! DANGER : NOARCHIVELOG = pas de PITR'
       END                                                       AS resultat
  FROM v$database
UNION ALL
SELECT 'Force Logging'
      ,CASE WHEN force_logging = 'YES'
            THEN 'OK (FORCE LOGGING actif)'
            ELSE 'ATTENTION : operations NOLOGGING possibles'
       END
  FROM v$database
UNION ALL
SELECT 'Nombre de groupes'
      ,CASE WHEN (SELECT COUNT(DISTINCT group#) FROM v$log) >= 3
            THEN 'OK (' || TRIM(TO_CHAR((SELECT COUNT(DISTINCT group#) FROM v$log), '999')) || ' groupes)'
            ELSE '!! RISQUE : minimum 3 groupes recommande'
       END
  FROM dual
UNION ALL
SELECT 'Multiplexage (membres par groupe)'
      ,CASE WHEN (SELECT MIN(members) FROM v$log) >= 2
            THEN 'OK (min ' || TRIM(TO_CHAR((SELECT MIN(members) FROM v$log), '999')) || ' membres)'
            ELSE '!! CRITIQUE : groupe(s) avec 1 seul membre'
       END
  FROM dual
UNION ALL
SELECT 'Taille uniforme des groupes'
      ,CASE WHEN (SELECT COUNT(DISTINCT bytes) FROM v$log) = 1
            THEN 'OK (tous identiques)'
            ELSE 'ATTENTION : tailles differentes entre groupes'
       END
  FROM dual
;

PROMPT
PROMPT  NOARCHIVELOG en prod      = perte donnees garantie en cas de crash
PROMPT  Force Logging = NO       = risque de trous dans les archives
PROMPT  1 seul membre par groupe = corruption redo = PERTE DE BASE
PROMPT  < 3 groupes              = risque de contention LGWR
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_7
