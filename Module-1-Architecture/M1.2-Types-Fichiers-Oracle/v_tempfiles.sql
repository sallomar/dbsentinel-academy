-- ============================================================================
-- SCRIPT     : v_tempfiles.sql
-- MODULE     : M1.2 - Les 5 Types de Fichiers Oracle
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_tempfiles.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== TEMPFILES ====================
PROMPT

COL file_id FORMAT 999 HEAD "ID"
COL tablespace_name FORMAT A15 HEAD "Tablespace"
COL file_name FORMAT A55 HEAD "Chemin Fichier"
COL taille_mo FORMAT 999,999 HEAD "Mo"
COL statut FORMAT A10 HEAD "Statut"

SELECT f.file# AS file_id,
       t.name AS tablespace_name,
       f.name AS file_name,
       ROUND(f.bytes/1024/1024) AS taille_mo,
       f.status AS statut
FROM v$tempfile f
JOIN v$tablespace t ON f.ts# = t.ts#
ORDER BY t.name, f.file#;

PROMPT

COL total_tempfiles FORMAT 999 HEAD "Total Tempfiles"
COL taille_go FORMAT 999.99 HEAD "Taille Go"

SELECT COUNT(*) AS total_tempfiles,
       ROUND(SUM(bytes)/1024/1024/1024, 2) AS taille_go
FROM v$tempfile;

PROMPT
PROMPT ===================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_2
