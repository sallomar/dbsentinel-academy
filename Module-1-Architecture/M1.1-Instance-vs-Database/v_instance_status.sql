-- ============================================================================
-- SCRIPT     : v_instance_status.sql
-- MODULE     : M1.1 - Instance vs Database
-- OBJECTIF   : Etat de l'instance Oracle
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_instance_status.sql
-- PREREQUIS  : SYSDBA, SELECT ANY DICTIONARY ou SELECT_CATALOG_ROLE
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 50
SET FEEDBACK OFF

COL instance_name FORMAT A12  HEAD "Instance"
COL status        FORMAT A8   HEAD "Statut"
COL startup_time  FORMAT A20  HEAD "Demarrage"
COL logins        FORMAT A10  HEAD "Logins"
COL version       FORMAT A12  HEAD "Version"
COL host_name     FORMAT A25  HEAD "Serveur"

PROMPT
PROMPT ================== ETAT INSTANCE ==================
PROMPT

SELECT instance_name,
       status,
       TO_CHAR(startup_time, 'DD/MM/YYYY HH24:MI:SS') startup_time,
       logins,
       version,
       host_name
FROM   v$instance;

PROMPT
PROMPT  Statut : STARTED=NOMOUNT | MOUNTED=MOUNT | OPEN=Production
PROMPT  Logins : ALLOWED=OK | RESTRICTED=Maintenance
PROMPT
PROMPT ===================================================
PROMPT

SET FEEDBACK ON
CLEAR COLUMNS

-- ============================================================================
-- DBSentinel Academy - Formation Oracle gratuite
-- ============================================================================
