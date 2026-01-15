-- ============================================================================
-- SCRIPT     : v_database_status.sql
-- MODULE     : M1.1 - Instance vs Database
-- OBJECTIF   : Etat de la database Oracle
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_database_status.sql
-- PREREQUIS  : SYSDBA, SELECT ANY DICTIONARY ou SELECT_CATALOG_ROLE
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 50
SET FEEDBACK OFF

COL dbid          FORMAT 9999999999 HEAD "DBID"
COL name          FORMAT A10  HEAD "Base"
COL open_mode     FORMAT A12  HEAD "Mode"
COL log_mode      FORMAT A12  HEAD "Archivage"
COL database_role FORMAT A16  HEAD "Role"
COL created       FORMAT A12  HEAD "Creation"

PROMPT
PROMPT ================== ETAT DATABASE ==================
PROMPT

SELECT dbid,
       name,
       open_mode,
       log_mode,
       database_role,
       TO_CHAR(created, 'DD/MM/YYYY') created
FROM   v$database;

PROMPT
PROMPT  Mode     : READ WRITE=Prod | READ ONLY=Standby | MOUNTED=Maintenance
PROMPT  Archivage: ARCHIVELOG=Backup chaud | NOARCHIVELOG=Backup froid
PROMPT
PROMPT ===================================================
PROMPT

SET FEEDBACK ON
CLEAR COLUMNS

-- ============================================================================
-- DBSentinel Academy - Formation Oracle gratuite
-- ============================================================================
