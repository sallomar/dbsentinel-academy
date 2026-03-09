-- ============================================================================
-- SCRIPT     : check_alertlog.sql
-- MODULE     : M1.3 - Alert.log : Detecter les signaux faibles
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @check_alertlog.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== ALERT.LOG - DIAGNOSTIC RAPIDE ====================
PROMPT

-- -----------------------------------------------
-- 1. Localisation et etat
-- -----------------------------------------------

COL nom    FORMAT A25 HEAD "Information"
COL valeur FORMAT A75 HEAD "Valeur"

SELECT name AS nom, value AS valeur
FROM   v$diag_info
WHERE  name IN ('ADR Home', 'Diag Trace',
                'Active Problem Count', 'Active Incident Count')
ORDER BY CASE name
           WHEN 'ADR Home'              THEN 1
           WHEN 'Diag Trace'            THEN 2
           WHEN 'Active Problem Count'  THEN 3
           WHEN 'Active Incident Count' THEN 4
         END;

-- -----------------------------------------------
-- 2. Erreurs ORA- classees par gravite (7 jours)
-- -----------------------------------------------

PROMPT
PROMPT  Erreurs ORA- par gravite (7 derniers jours) :
PROMPT  (si aucune ligne = alert.log propre)
PROMPT

COL gravite   FORMAT A12 HEAD "Gravite"
COL categorie FORMAT A30 HEAD "Categorie"
COL nb        FORMAT 999 HEAD "Nb"

WITH erreurs AS (
  SELECT REGEXP_SUBSTR(message_text, 'ORA-[0-9]+') AS ora_code
  FROM   v$diag_alert_ext
  WHERE  originating_timestamp > SYSDATE - 7
    AND  message_text LIKE '%ORA-%'
)
SELECT CASE
         WHEN ora_code IN ('ORA-00600','ORA-07445')
           THEN 'CRITIQUE'
         WHEN ora_code IN ('ORA-01578','ORA-00312','ORA-27048')
           THEN 'CRITIQUE'
         WHEN ora_code IN ('ORA-01653','ORA-01652','ORA-00257')
           THEN 'BLOQUANT'
         WHEN ora_code IN ('ORA-01555','ORA-04031')
           THEN 'WARNING'
         WHEN ora_code IN ('ORA-12012','ORA-12008','ORA-06512')
           THEN 'INFO'
         ELSE 'A VERIFIER'
       END AS gravite,
       CASE
         WHEN ora_code IN ('ORA-00600','ORA-07445')
           THEN 'Bug interne Oracle'
         WHEN ora_code IN ('ORA-01578','ORA-00312','ORA-27048')
           THEN 'Corruption fichier'
         WHEN ora_code IN ('ORA-01653','ORA-01652','ORA-00257')
           THEN 'Espace disque sature'
         WHEN ora_code = 'ORA-01555'
           THEN 'Undo/Snapshot too old'
         WHEN ora_code = 'ORA-04031'
           THEN 'Shared Pool sature'
         WHEN ora_code IN ('ORA-12012','ORA-12008')
           THEN 'Erreur Job Scheduler'
         WHEN ora_code = 'ORA-06512'
           THEN 'Erreur PL/SQL (stack)'
         ELSE ora_code
       END AS categorie,
       COUNT(*) AS nb
FROM   erreurs
WHERE  ora_code IS NOT NULL
GROUP BY
       CASE
         WHEN ora_code IN ('ORA-00600','ORA-07445') THEN 'CRITIQUE'
         WHEN ora_code IN ('ORA-01578','ORA-00312','ORA-27048') THEN 'CRITIQUE'
         WHEN ora_code IN ('ORA-01653','ORA-01652','ORA-00257') THEN 'BLOQUANT'
         WHEN ora_code IN ('ORA-01555','ORA-04031') THEN 'WARNING'
         WHEN ora_code IN ('ORA-12012','ORA-12008','ORA-06512') THEN 'INFO'
         ELSE 'A VERIFIER'
       END,
       CASE
         WHEN ora_code IN ('ORA-00600','ORA-07445') THEN 'Bug interne Oracle'
         WHEN ora_code IN ('ORA-01578','ORA-00312','ORA-27048') THEN 'Corruption fichier'
         WHEN ora_code IN ('ORA-01653','ORA-01652','ORA-00257') THEN 'Espace disque sature'
         WHEN ora_code = 'ORA-01555' THEN 'Undo/Snapshot too old'
         WHEN ora_code = 'ORA-04031' THEN 'Shared Pool sature'
         WHEN ora_code IN ('ORA-12012','ORA-12008') THEN 'Erreur Job Scheduler'
         WHEN ora_code = 'ORA-06512' THEN 'Erreur PL/SQL (stack)'
         ELSE ora_code
       END
ORDER BY DECODE(
           CASE
             WHEN ora_code IN ('ORA-00600','ORA-07445') THEN 'CRITIQUE'
             WHEN ora_code IN ('ORA-01578','ORA-00312','ORA-27048') THEN 'CRITIQUE'
             WHEN ora_code IN ('ORA-01653','ORA-01652','ORA-00257') THEN 'BLOQUANT'
             WHEN ora_code IN ('ORA-01555','ORA-04031') THEN 'WARNING'
             WHEN ora_code IN ('ORA-12012','ORA-12008','ORA-06512') THEN 'INFO'
             ELSE 'A VERIFIER'
           END,
           'CRITIQUE', 1, 'BLOQUANT', 2, 'WARNING', 3, 'INFO', 4, 5),
         nb DESC;

-- -----------------------------------------------
-- 3. Derniers messages ORA- (messages utiles)
-- -----------------------------------------------

PROMPT
PROMPT  5 dernieres erreurs ORA- (message) :
PROMPT

COL quand   FORMAT A14  HEAD "Date/Heure"
COL code    FORMAT A12  HEAD "Code"
COL message FORMAT A85  HEAD "Message"

SELECT quand, code, message
FROM (
  SELECT TO_CHAR(originating_timestamp, 'DD/MM HH24:MI:SS') AS quand,
         REGEXP_SUBSTR(message_text, 'ORA-[0-9]+') AS code,
         REGEXP_SUBSTR(message_text, 'ORA-[0-9]+: .+') AS message
  FROM   v$diag_alert_ext
  WHERE  originating_timestamp > SYSDATE - 7
    AND  message_text LIKE '%ORA-%'
    AND  REGEXP_SUBSTR(message_text, 'ORA-[0-9]+: .+') IS NOT NULL
  ORDER BY originating_timestamp DESC
)
WHERE ROWNUM <= 5;

PROMPT
PROMPT  Temps reel : tail -f <Diag Trace>/alert_<SID>.log
PROMPT
PROMPT =====================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_3
