-- ============================================================================
-- SCRIPT     : check_controlfile.sql
-- MODULE     : M1.8 - Control Files
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @check_controlfile.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== CONTROL FILES - DIAGNOSTIC RAPIDE ====================
PROMPT

-- -----------------------------------------------
-- 1. Liste des control files
-- -----------------------------------------------

COL grp_id    FORMAT 999     HEAD "#"
COL fichier   FORMAT A75     HEAD "Control File"
COL taille    FORMAT A10     HEAD "Taille"
COL statut    FORMAT A10     HEAD "Statut"

SELECT ROWNUM                                                    AS grp_id
      ,name                                                      AS fichier
      ,LPAD(TRIM(TO_CHAR(file_size_blks * block_size / 1048576, '999.9')) || ' MB', 8) AS taille
      ,NVL(status, 'OK')                                         AS statut
  FROM v$controlfile
 ORDER BY name
;

PROMPT
PROMPT  Identite de la base :
PROMPT

-- -----------------------------------------------
-- 2. Identite et metadonnees critiques
-- -----------------------------------------------

COL information FORMAT A40  HEAD "Information"
COL valeur      FORMAT A50  HEAD "Valeur"

SELECT 'DBID (identifiant unique base)'                          AS information
      ,TRIM(TO_CHAR(dbid))                                       AS valeur
  FROM v$database
UNION ALL
SELECT 'Nom de la base'
      ,name
  FROM v$database
UNION ALL
SELECT 'Date de creation'
      ,TO_CHAR(created, 'DD/MM/YYYY HH24:MI:SS')
  FROM v$database
UNION ALL
SELECT 'Type Control File'
      ,controlfile_type
  FROM v$database
UNION ALL
SELECT 'Sequence Control File'
      ,TRIM(TO_CHAR(controlfile_sequence#, '999,999,999'))
  FROM v$database
UNION ALL
SELECT 'Checkpoint SCN courant'
      ,TRIM(TO_CHAR(checkpoint_change#, '999,999,999,999'))
  FROM v$database
;

PROMPT
PROMPT  Verification securite :
PROMPT

-- -----------------------------------------------
-- 3. Alertes de configuration critiques
-- -----------------------------------------------

COL element   FORMAT A40  HEAD "Verification"
COL resultat  FORMAT A55  HEAD "Resultat"

SELECT 'Nombre de copies multiplexees'                           AS element
      ,CASE WHEN COUNT(*) >= 3 THEN 'OK (' || COUNT(*) || ' copies)'
            WHEN COUNT(*) = 2 THEN '!! INSUFFISANT : 2 copies (3 recommandees)'
            ELSE '!! CRITIQUE : 1 seule copie = risque PERTE BASE'
       END                                                       AS resultat
  FROM v$controlfile
UNION ALL
SELECT 'Statut des control files'
      ,CASE WHEN SUM(CASE WHEN status IS NOT NULL THEN 1 ELSE 0 END) = 0
            THEN 'OK : tous les CF sont valides'
            ELSE '!! ALERTE : ' || SUM(CASE WHEN status IS NOT NULL THEN 1 ELSE 0 END)
                 || ' CF en erreur'
       END
  FROM v$controlfile
UNION ALL
SELECT 'Disques utilises (placement)'
      ,CASE WHEN COUNT(DISTINCT SUBSTR(name, 1, 3)) >= 3
            THEN 'OK : CF sur ' || COUNT(DISTINCT SUBSTR(name, 1, 3))
                 || ' disques differents'
            WHEN COUNT(DISTINCT SUBSTR(name, 1, 3)) = 2
            THEN 'A AMELIORER : seulement 2 disques distincts'
            ELSE '!! CRITIQUE : tous les CF sur le meme disque'
       END
  FROM v$controlfile
UNION ALL
SELECT 'Type Control File'
      ,CASE WHEN controlfile_type = 'CURRENT'
            THEN 'OK (CURRENT = production normale)'
            WHEN controlfile_type = 'STANDBY'
            THEN 'INFO : base STANDBY (Data Guard)'
            ELSE 'INFO : type = ' || controlfile_type
       END
  FROM v$database
;

PROMPT
PROMPT  Regle des 3 copies : majorite gagne (tiebreaker)
PROMPT  2 copies seulement = SHUTDOWN IMMEDIATE bloque si 1 corruption
PROMPT  1 seule copie     = perte CF = base inutilisable, DBID perdu
PROMPT  3 copies sur 3 disques differents = norme production
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_8
