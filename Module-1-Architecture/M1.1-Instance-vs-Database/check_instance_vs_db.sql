-- ============================================================================
-- SCRIPT     : check_instance_vs_db.sql
-- MODULE     : M1.1 - Instance vs Database
-- OBJECTIF   : Vue synthetique Instance vs Database
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @check_instance_vs_db.sql
-- PREREQUIS  : SYSDBA, SELECT ANY DICTIONARY ou SELECT_CATALOG_ROLE
-- GUIDE      : Voir README.md pour guide complet debutant
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF
SET VERIFY OFF

-- ============================================================================
-- INSTANCE (Memoire + Processus) - TEMPORAIRE
-- ============================================================================

PROMPT
PROMPT ================== INSTANCE (TEMPORAIRE) ==================
PROMPT

COL instance_name FORMAT A12  HEAD "Instance"
COL status        FORMAT A8   HEAD "Statut"
COL startup_time  FORMAT A20  HEAD "Demarrage"
COL host_name     FORMAT A20  HEAD "Serveur"

SELECT instance_name,
       status,
       TO_CHAR(startup_time, 'DD/MM/YYYY HH24:MI:SS') startup_time,
       host_name
FROM   v$instance;

PROMPT
PROMPT  Memoire Instance (SGA + PGA) :
PROMPT

COL composant FORMAT A20 HEAD "Composant"
COL taille_mo FORMAT 999,999 HEAD "Mo"

SELECT 'SGA (partagee)' composant,
       ROUND(SUM(value)/1024/1024) taille_mo
FROM   v$sga
UNION ALL
SELECT 'PGA (privee)',
       ROUND(value/1024/1024)
FROM   v$pgastat
WHERE  name = 'total PGA allocated'
UNION ALL
SELECT '--- TOTAL MEMOIRE ---',
       ROUND((SELECT SUM(value) FROM v$sga)/1024/1024 +
             (SELECT value FROM v$pgastat WHERE name = 'total PGA allocated')/1024/1024)
FROM   dual;

PROMPT
PROMPT  Processus background actifs :

SELECT COUNT(*) || ' processus actifs' AS "Nb Processus"
FROM   v$bgprocess
WHERE  paddr <> '00';

-- ============================================================================
-- DATABASE (Fichiers sur disque) - PERMANENT
-- ============================================================================

PROMPT
PROMPT ================== DATABASE (PERMANENT) ==================
PROMPT

COL name          FORMAT A12  HEAD "Base"
COL open_mode     FORMAT A12  HEAD "Mode"
COL log_mode      FORMAT A12  HEAD "Archivage"
COL database_role FORMAT A10  HEAD "Role"

SELECT name,
       open_mode,
       log_mode,
       database_role
FROM   v$database;

PROMPT
PROMPT  Fichiers sur disque :
PROMPT

COL file_type FORMAT A15 HEAD "Type Fichier"
COL cnt       FORMAT 999 HEAD "Nb"

SELECT 'DATAFILES' file_type, COUNT(*) cnt FROM v$datafile
UNION ALL
SELECT 'REDO LOGS', COUNT(*) FROM v$log
UNION ALL
SELECT 'CONTROL FILES', COUNT(*) FROM v$controlfile
UNION ALL
SELECT 'TEMP FILES', COUNT(*) FROM v$tempfile;

-- ============================================================================
-- RESUME CONCEPTUEL
-- ============================================================================

PROMPT
PROMPT ====================== RESUME M1.1 ======================
PROMPT
PROMPT  INSTANCE = Memoire (SGA+PGA) + Processus --> TEMPORAIRE
PROMPT             Disparait au SHUTDOWN
PROMPT
PROMPT  DATABASE = Fichiers sur disque           --> PERMANENT
PROMPT             Reste intact au SHUTDOWN
PROMPT
PROMPT  REGLE D'OR : SHUTDOWN = couper le moteur, pas detruire la voiture
PROMPT
PROMPT ==========================================================
PROMPT

SET FEEDBACK ON
SET VERIFY ON
CLEAR COLUMNS

-- ============================================================================
-- DBSentinel Academy - Formation Oracle gratuite
-- Theorie complete : Carrousel M1.1 sur LinkedIn
-- ============================================================================
