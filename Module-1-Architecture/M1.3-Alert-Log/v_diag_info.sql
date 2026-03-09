-- ============================================================================
-- SCRIPT     : v_diag_info.sql
-- MODULE     : M1.3 - Alert.log : Detecter les signaux faibles
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_diag_info.sql
-- ============================================================================

SET LINESIZE 250
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== STRUCTURE ADR (Automatic Diagnostic Repository) ====================
PROMPT

COL nom    FORMAT A25  HEAD "Composant ADR"
COL valeur FORMAT A80  HEAD "Chemin / Valeur"

SELECT name AS nom, value AS valeur
FROM   v$diag_info
ORDER BY CASE name
           WHEN 'ADR Base'              THEN 1
           WHEN 'ADR Home'              THEN 2
           WHEN 'Diag Trace'            THEN 3
           WHEN 'Diag Alert'            THEN 4
           WHEN 'Diag Incident'         THEN 5
           WHEN 'Diag Cdump'            THEN 6
           WHEN 'Health Monitor'        THEN 7
           WHEN 'Default Trace File'    THEN 8
           WHEN 'Active Problem Count'  THEN 9
           WHEN 'Active Incident Count' THEN 10
           ELSE 11
         END;

PROMPT
PROMPT  ADR Base      = Racine diagnostique Oracle
PROMPT  Diag Trace    = Contient alert_SID.log + fichiers .trc
PROMPT  Diag Alert    = Contient log.xml (format XML)
PROMPT  Diag Incident = Incidents Oracle (ORA-600, ORA-7445)
PROMPT
PROMPT ========================================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_3
