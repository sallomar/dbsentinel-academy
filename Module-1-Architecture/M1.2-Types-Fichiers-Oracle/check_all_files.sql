-- ============================================================================
-- SCRIPT     : check_all_files.sql
-- MODULE     : M1.2 - Les 5 Types de Fichiers Oracle
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @check_all_files.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== LES 5 TYPES DE FICHIERS ORACLE ====================
PROMPT

COL type_fichier FORMAT A15 HEAD "Type Fichier"
COL nb FORMAT 999 HEAD "Nb"
COL taille_mo FORMAT 999,999 HEAD "Mo"
COL role_fichier FORMAT A35 HEAD "Role"

SELECT 'DATAFILES' AS type_fichier,
       COUNT(*) AS nb,
       ROUND(SUM(bytes)/1024/1024) AS taille_mo,
       'Donnees permanentes' AS role_fichier
FROM v$datafile
UNION ALL
SELECT 'TEMPFILES',
       COUNT(*),
       ROUND(SUM(bytes)/1024/1024),
       'Donnees temporaires (tris)'
FROM v$tempfile
UNION ALL
SELECT 'REDO LOGS',
       COUNT(DISTINCT f.group#),
       ROUND(SUM(DISTINCT g.bytes)/1024/1024),
       'Journalisation transactions'
FROM v$logfile f
JOIN v$log g ON f.group# = g.group#
UNION ALL
SELECT 'CONTROL FILES',
       COUNT(*),
       ROUND(SUM(block_size * file_size_blks)/1024/1024),
       'Metadonnees base'
FROM v$controlfile;

PROMPT
COL archivelog_mode FORMAT A15 HEAD "Mode Archivage"
SELECT log_mode AS archivelog_mode FROM v$database;

PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_2
