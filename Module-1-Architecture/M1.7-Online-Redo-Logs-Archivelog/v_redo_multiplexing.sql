-- ============================================================================
-- SCRIPT     : v_redo_multiplexing.sql
-- MODULE     : M1.7 - Online Redo Logs et Archivelog
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_redo_multiplexing.sql
-- ============================================================================

SET LINESIZE 250
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== REDO LOGS - MULTIPLEXAGE ET SECURITE ====================
PROMPT

-- -----------------------------------------------
-- 1. Detail membres par groupe
-- -----------------------------------------------

COL grp      FORMAT 999    HEAD "Grp"
COL membre   FORMAT A70    HEAD "Membre (chemin physique)"
COL mbr_stat FORMAT A12    HEAD "Statut Mbr"
COL grp_stat FORMAT A10    HEAD "Statut Grp"
COL taille   FORMAT A8     HEAD "Mo"

SELECT l.group#                                                  AS grp
      ,f.member                                                  AS membre
      ,f.status                                                  AS mbr_stat
      ,l.status                                                  AS grp_stat
      ,LPAD(TRIM(TO_CHAR(l.bytes/1048576, '999')), 6)           AS taille
  FROM v$logfile f
  JOIN v$log l ON f.group# = l.group#
 ORDER BY l.group#, f.member
;

PROMPT
PROMPT  Analyse multiplexage :
PROMPT

-- -----------------------------------------------
-- 2. Resume multiplexage par groupe
-- -----------------------------------------------

COL grp      FORMAT 999    HEAD "Grp"
COL membres  FORMAT 99     HEAD "Mbr"
COL statut   FORMAT A10    HEAD "Statut"
COL disques  FORMAT A60    HEAD "Disques/Repertoires utilises"
COL securite FORMAT A20    HEAD "Securite"

SELECT l.group#                                                  AS grp
      ,l.members                                                 AS membres
      ,l.status                                                  AS statut
      ,LISTAGG(
          SUBSTR(f.member, 1, INSTR(f.member, '\', -1))
          , ' | '
       ) WITHIN GROUP (ORDER BY f.member)                        AS disques
      ,CASE WHEN l.members >= 2
            THEN 'OK (multiplex)'
            ELSE '!! 1 MEMBRE SEUL'
       END                                                       AS securite
  FROM v$log l
  JOIN v$logfile f ON l.group# = f.group#
 GROUP BY l.group#, l.members, l.status
 ORDER BY l.group#
;

PROMPT
PROMPT  Verification globale :
PROMPT

-- -----------------------------------------------
-- 3. Synthese securite
-- -----------------------------------------------

COL element   FORMAT A45  HEAD "Verification"
COL resultat  FORMAT A40  HEAD "Resultat"

SELECT 'Groupes avec 1 seul membre'                             AS element
      ,CASE WHEN COUNT(*) = 0
            THEN 'OK : tous les groupes sont multiplexes'
            ELSE '!! CRITIQUE : ' || TRIM(TO_CHAR(COUNT(*), '999'))
                 || ' groupe(s) sans redondance'
       END                                                       AS resultat
  FROM v$log
 WHERE members = 1
UNION ALL
SELECT 'Membres avec statut INVALID ou STALE'
      ,CASE WHEN COUNT(*) = 0
            THEN 'OK : tous les membres sont valides'
            ELSE '!! ALERTE : ' || TRIM(TO_CHAR(COUNT(*), '999'))
                 || ' membre(s) en erreur'
       END
  FROM v$logfile
 WHERE status IN ('INVALID', 'STALE')
;

PROMPT
PROMPT  1 seul membre par groupe = corruption redo possible = PERTE DE BASE
PROMPT  Regle : minimum 2 membres par groupe sur disques DIFFERENTS
PROMPT  Membre INVALID/STALE    --> Recreer le membre immediatement
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_7
