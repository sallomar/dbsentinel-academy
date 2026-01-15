-- ============================================================================
-- SCRIPT     : v_datafiles.sql
-- MODULE     : M1.2 - Les 5 Types de Fichiers Oracle
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_datafiles.sql
-- ============================================================================

SET LINESIZE 250
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== DATAFILES ====================
PROMPT

COL file_id FORMAT 999 HEAD "ID"
COL tablespace_name FORMAT A20 HEAD "Tablespace"
COL file_name FORMAT A60 HEAD "Chemin Fichier"
COL taille_mo FORMAT 999,999 HEAD "Mo"
COL statut FORMAT A10 HEAD "Statut"

SELECT f.file# AS file_id,
       t.name AS tablespace_name,
       f.name AS file_name,
       ROUND(f.bytes/1024/1024) AS taille_mo,
       f.status AS statut
FROM v$datafile f
JOIN v$tablespace t ON f.ts# = t.ts#
ORDER BY t.name, f.file#;

PROMPT

COL tablespace_name FORMAT A20 HEAD "Tablespace"
COL nb_fichiers FORMAT 999 HEAD "Nb"
COL taille_mo FORMAT 999,999 HEAD "Mo"

SELECT t.name AS tablespace_name,
       COUNT(*) AS nb_fichiers,
       ROUND(SUM(f.bytes)/1024/1024) AS taille_mo
FROM v$datafile f
JOIN v$tablespace t ON f.ts# = t.ts#
GROUP BY t.name
ORDER BY taille_mo DESC;

PROMPT

COL total_datafiles FORMAT 999 HEAD "Total Datafiles"
COL taille_go FORMAT 999.99 HEAD "Taille Go"

SELECT COUNT(*) AS total_datafiles,
       ROUND(SUM(bytes)/1024/1024/1024, 2) AS taille_go
FROM v$datafile;

PROMPT
PROMPT ===================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_2
