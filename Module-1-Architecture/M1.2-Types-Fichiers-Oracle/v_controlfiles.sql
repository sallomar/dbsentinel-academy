-- ============================================================================
-- SCRIPT     : v_controlfiles.sql
-- MODULE     : M1.2 - Les 5 Types de Fichiers Oracle
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_controlfiles.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== CONTROL FILES ====================
PROMPT

COL control_file FORMAT A70 HEAD "Chemin Control File"
COL statut FORMAT A10 HEAD "Statut"
COL taille_mo FORMAT 999.99 HEAD "Mo"

SELECT name AS control_file,
       status AS statut,
       ROUND(block_size * file_size_blks / 1024 / 1024, 2) AS taille_mo
FROM v$controlfile
ORDER BY name;

PROMPT

COL multiplexage FORMAT A55 HEAD "Multiplexage"

SELECT CASE
         WHEN COUNT(*) >= 3 THEN 'OK - ' || COUNT(*) || ' copies'
         WHEN COUNT(*) = 2 THEN 'ATTENTION - 2 copies (recommande : 3)'
         ELSE 'CRITIQUE - 1 seul control file !'
       END AS multiplexage
FROM v$controlfile;

PROMPT
PROMPT ======================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_2
