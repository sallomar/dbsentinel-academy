-- ============================================================================
-- SCRIPT     : v_alert_errors.sql
-- MODULE     : M1.3 - Alert.log : Detecter les signaux faibles
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_alert_errors.sql
-- ============================================================================

SET LINESIZE 250
SET PAGESIZE 100
SET FEEDBACK OFF

-- -----------------------------------------------
-- 1. Top erreurs ORA- par code (30 jours)
-- -----------------------------------------------

PROMPT
PROMPT ==================== ERREURS ORA- : ANALYSE 30 JOURS ====================
PROMPT

COL ora_code    FORMAT A12  HEAD "Code ORA-"
COL occurrences FORMAT 999  HEAD "Nb"
COL derniere    FORMAT A16  HEAD "Derniere fois"
COL diagnostic  FORMAT A35  HEAD "Diagnostic"

WITH erreurs_brutes AS (
  SELECT REGEXP_SUBSTR(message_text, 'ORA-[0-9]+') AS ora_code,
         originating_timestamp
  FROM   v$diag_alert_ext
  WHERE  originating_timestamp > SYSDATE - 30
    AND  message_text LIKE '%ORA-%'
),
stats AS (
  SELECT ora_code,
         COUNT(*)                   AS occurrences,
         MAX(originating_timestamp) AS derniere_ts
  FROM   erreurs_brutes
  WHERE  ora_code IS NOT NULL
  GROUP BY ora_code
)
SELECT ora_code,
       occurrences,
       TO_CHAR(derniere_ts, 'DD/MM/YY HH24:MI') AS derniere,
       CASE
         WHEN ora_code = 'ORA-00600'  THEN 'CRITIQUE - Bug interne Oracle'
         WHEN ora_code = 'ORA-07445'  THEN 'CRITIQUE - Exception systeme'
         WHEN ora_code = 'ORA-01578'  THEN 'CRITIQUE - Block corruption'
         WHEN ora_code = 'ORA-00312'  THEN 'CRITIQUE - Redo log manquant'
         WHEN ora_code = 'ORA-27048'  THEN 'CRITIQUE - Fichier introuvable'
         WHEN ora_code = 'ORA-01653'  THEN 'BLOQUANT - Tablespace plein'
         WHEN ora_code = 'ORA-01652'  THEN 'BLOQUANT - Temp plein'
         WHEN ora_code = 'ORA-00257'  THEN 'BLOQUANT - Archives pleines'
         WHEN ora_code = 'ORA-01555'  THEN 'WARNING  - Snapshot too old'
         WHEN ora_code = 'ORA-04031'  THEN 'WARNING  - Shared Pool sature'
         WHEN ora_code = 'ORA-12012'  THEN 'INFO     - Erreur job scheduler'
         WHEN ora_code = 'ORA-12008'  THEN 'INFO     - Erreur job chaine'
         WHEN ora_code = 'ORA-06512'  THEN 'INFO     - Stack PL/SQL'
         WHEN ora_code = 'ORA-04036'  THEN 'WARNING  - PGA limite atteinte'
         WHEN ora_code = 'ORA-01110'  THEN 'INFO     - Datafile reference'
         WHEN ora_code = 'ORA-00060'  THEN 'WARNING  - Deadlock detecte'
         WHEN ora_code = 'ORA-30036'  THEN 'BLOQUANT - Undo segment plein'
         ELSE 'A VERIFIER'
       END AS diagnostic
FROM   stats
ORDER BY CASE
           WHEN ora_code IN ('ORA-00600','ORA-07445')             THEN 1
           WHEN ora_code IN ('ORA-01578','ORA-00312','ORA-27048') THEN 2
           WHEN ora_code IN ('ORA-01653','ORA-01652','ORA-00257','ORA-30036') THEN 3
           WHEN ora_code IN ('ORA-01555','ORA-04031','ORA-04036','ORA-00060') THEN 4
           WHEN ora_code IN ('ORA-12012','ORA-12008','ORA-06512','ORA-01110') THEN 5
           ELSE 6
         END,
         occurrences DESC;

-- -----------------------------------------------
-- 2. Signaux performance
-- -----------------------------------------------

PROMPT
PROMPT  Signaux performance (30 derniers jours) :
PROMPT

COL signal     FORMAT A30  HEAD "Signal"
COL nb_signaux FORMAT 9999 HEAD "Nb"
COL derniere   FORMAT A16  HEAD "Derniere fois"

SELECT signal, nb_signaux, derniere
FROM (
  SELECT 'checkpoint not complete' AS signal,
         COUNT(*) AS nb_signaux,
         TO_CHAR(MAX(originating_timestamp), 'DD/MM/YY HH24:MI') AS derniere
  FROM   v$diag_alert_ext
  WHERE  originating_timestamp > SYSDATE - 30
    AND  LOWER(message_text) LIKE '%checkpoint not complete%'
)
WHERE nb_signaux > 0
UNION ALL
SELECT signal, nb_signaux, derniere
FROM (
  SELECT 'log file switch (archiving)' AS signal,
         COUNT(*) AS nb_signaux,
         TO_CHAR(MAX(originating_timestamp), 'DD/MM/YY HH24:MI') AS derniere
  FROM   v$diag_alert_ext
  WHERE  originating_timestamp > SYSDATE - 30
    AND  LOWER(message_text) LIKE '%log file switch%archiv%'
)
WHERE nb_signaux > 0;

PROMPT
PROMPT  Actions par gravite :
PROMPT  CRITIQUE : ORA-600, ORA-7445       --> Support Oracle immediat
PROMPT  CRITIQUE : ORA-1578, ORA-312       --> Recovery RMAN
PROMPT  BLOQUANT : ORA-1653, ORA-257       --> Etendre tablespace ou purger
PROMPT  WARNING  : checkpoint not complete  --> Augmenter taille redo logs
PROMPT
PROMPT =========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_3
