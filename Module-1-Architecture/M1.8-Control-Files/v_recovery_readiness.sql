-- ============================================================================
-- SCRIPT     : v_recovery_readiness.sql
-- MODULE     : M1.8 - Control Files
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_recovery_readiness.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== RECOVERY READINESS - SUIS-JE PRET ? ====================
PROMPT

-- -----------------------------------------------
-- 1. Audit pre-disaster (8 verifications)
-- -----------------------------------------------

COL controle  FORMAT A45  HEAD "Controle"
COL etat      FORMAT A55  HEAD "Etat"

SELECT 'Control Files - Nombre de copies'                        AS controle
      ,CASE WHEN (SELECT COUNT(*) FROM v$controlfile) >= 3
            THEN 'OK : ' || (SELECT COUNT(*) FROM v$controlfile) || ' copies'
            ELSE '!! INSUFFISANT : ' || (SELECT COUNT(*) FROM v$controlfile) || ' copie(s)'
       END                                                       AS etat
  FROM dual
UNION ALL
SELECT 'Mode archivage (PITR possible ?)'
      ,CASE WHEN log_mode = 'ARCHIVELOG'
            THEN 'OK : ARCHIVELOG (PITR possible)'
            ELSE '!! DANGER : NOARCHIVELOG (pas de PITR)'
       END
  FROM v$database
UNION ALL
SELECT 'Force Logging (operations NOLOGGING ?)'
      ,CASE WHEN force_logging = 'YES'
            THEN 'OK : FORCE LOGGING actif'
            ELSE 'ATTENTION : NOLOGGING possible (trous archives)'
       END
  FROM v$database
UNION ALL
SELECT 'DBID (necessaire pour RMAN)'
      ,'OK : DBID = ' || dbid
  FROM v$database
UNION ALL
SELECT 'Dernier archive log genere'
      ,NVL(TO_CHAR(MAX(first_time), 'DD/MM/YYYY HH24:MI:SS'),
           '!! AUCUN ARCHIVE LOG (NOARCHIVELOG ?)')
  FROM v$archived_log
 WHERE deleted = 'NO'
UNION ALL
SELECT 'Archives disponibles sur disque'
      ,TRIM(TO_CHAR(COUNT(*), '999,999')) || ' archive(s) (deleted = NO)'
  FROM v$archived_log
 WHERE deleted = 'NO'
UNION ALL
SELECT 'Datafiles en backup mode (BEGIN BACKUP)'
      ,CASE WHEN COUNT(*) = 0
            THEN 'OK : aucun datafile en backup mode'
            ELSE '!! ATTENTION : ' || COUNT(*) || ' datafile(s) en BACKUP MODE'
       END
  FROM v$backup
 WHERE status = 'ACTIVE'
UNION ALL
SELECT 'Datafiles necessitant recovery'
      ,CASE WHEN COUNT(*) = 0
            THEN 'OK : aucun datafile en RECOVER'
            ELSE '!! CRITIQUE : ' || COUNT(*) || ' datafile(s) en recovery'
       END
  FROM v$datafile
 WHERE status = 'RECOVER'
;

PROMPT
PROMPT  Estimation RTO (Recovery Time Objective) :
PROMPT

-- -----------------------------------------------
-- 2. Scenarios de recovery
-- -----------------------------------------------

COL scenario     FORMAT A50  HEAD "Scenario disaster"
COL rto_estime   FORMAT A30  HEAD "RTO estime"
COL prerequis    FORMAT A35  HEAD "Prerequis"

SELECT '1 Control File perdu (multiplexe)'                       AS scenario
      ,'5 min (suppression init.ora)'                            AS rto_estime
      ,'>= 2 CF restants OK'                                     AS prerequis
  FROM dual
UNION ALL
SELECT 'Tous les CF perdus + Redo logs OK'
      ,'30 min (CREATE CONTROLFILE)'
      ,'Script BACKUP CF TO TRACE'
  FROM dual
UNION ALL
SELECT 'Tous les CF + Redo logs perdus'
      ,'2-8h (recovery RMAN incomplet)'
      ,'Backup RMAN + DBID + archives'
  FROM dual
UNION ALL
SELECT 'Crash disque total (perte BDD complete)'
      ,'8-24h (restauration RMAN)'
      ,'Backup RMAN externe + DBID'
  FROM dual
;

PROMPT
PROMPT  Actions critiques :
PROMPT  PAS d'ARCHIVELOG       --> activer en urgence (ALTER DATABASE ARCHIVELOG)
PROMPT  < 3 CF                  --> ajouter copies (CONTROL_FILES init.ora + restart)
PROMPT  DBID inconnu            --> noter dans runbook : sans DBID, recovery RMAN bloque
PROMPT  Backup CF to trace      --> generer regulierement (script de recreation)
PROMPT  RMAN AUTOBACKUP ON     --> configurer pour sauver CF a chaque modif
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_8
