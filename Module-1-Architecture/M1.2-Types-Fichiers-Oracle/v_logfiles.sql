-- ============================================================================
-- SCRIPT     : v_logfiles.sql
-- MODULE     : M1.2 - Les 5 Types de Fichiers Oracle
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_logfiles.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== REDO LOGS ====================
PROMPT

COL group_num FORMAT 999 HEAD "Grp"
COL sequence_num FORMAT 99999 HEAD "Seq#"
COL taille_mo FORMAT 999 HEAD "Mo"
COL group_status FORMAT A10 HEAD "Statut"
COL member_path FORMAT A50 HEAD "Chemin Membre"
COL member_status FORMAT A12 HEAD "Mbr Status"

SELECT g.group# AS group_num,
       g.sequence# AS sequence_num,
       ROUND(g.bytes/1024/1024) AS taille_mo,
       g.status AS group_status,
       m.member AS member_path,
       m.status AS member_status
FROM v$log g
JOIN v$logfile m ON g.group# = m.group#
ORDER BY g.group#, m.member;

PROMPT

COL nb_groupes FORMAT 999 HEAD "Groupes"
COL nb_membres FORMAT 999 HEAD "Membres"
COL taille_totale_mo FORMAT 999 HEAD "Mo Total"

SELECT COUNT(DISTINCT g.group#) AS nb_groupes,
       COUNT(*) AS nb_membres,
       ROUND(SUM(DISTINCT g.bytes)/1024/1024) AS taille_totale_mo
FROM v$log g
JOIN v$logfile m ON g.group# = m.group#;

PROMPT
PROMPT ===================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_2
