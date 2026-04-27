-- ============================================================================
-- SCRIPT     : v_fra_usage.sql
-- MODULE     : M1.7 - Online Redo Logs et Archivelog
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_fra_usage.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== FRA - FAST RECOVERY AREA ====================
PROMPT

-- -----------------------------------------------
-- 1. Configuration FRA
-- -----------------------------------------------

COL information FORMAT A40  HEAD "Configuration FRA"
COL valeur      FORMAT A50  HEAD "Valeur"

SELECT 'Emplacement FRA (DB_RECOVERY_FILE_DEST)'                 AS information
      ,value                                                     AS valeur
  FROM v$parameter
 WHERE name = 'db_recovery_file_dest'
UNION ALL
SELECT 'Taille FRA (DB_RECOVERY_FILE_DEST_SIZE)'
      ,CASE WHEN TO_NUMBER(value) > 0
            THEN TRIM(TO_CHAR(TO_NUMBER(value)/1073741824, '999.9')) || ' GB'
            ELSE 'NON CONFIGURE'
       END
  FROM v$parameter
 WHERE name = 'db_recovery_file_dest_size'
;

PROMPT
PROMPT  Espace FRA :
PROMPT

-- -----------------------------------------------
-- 2. Utilisation espace FRA
-- -----------------------------------------------

COL fra_taille   FORMAT A12  HEAD "Taille"
COL fra_utilise  FORMAT A12  HEAD "Utilise"
COL fra_libre    FORMAT A12  HEAD "Libre"
COL fra_recup    FORMAT A12  HEAD "Recuperable"
COL pct_utilise  FORMAT A8   HEAD "% Util"
COL statut       FORMAT A15  HEAD "Statut"

SELECT LPAD(TRIM(TO_CHAR(space_limit/1073741824, '999.9')) || ' GB', 10)  AS fra_taille
      ,LPAD(TRIM(TO_CHAR(space_used/1073741824, '999.9')) || ' GB', 10)   AS fra_utilise
      ,LPAD(TRIM(TO_CHAR((space_limit - space_used)/1073741824, '999.9')) || ' GB', 10) AS fra_libre
      ,LPAD(TRIM(TO_CHAR(space_reclaimable/1073741824, '999.9')) || ' GB', 10) AS fra_recup
      ,LPAD(TRIM(TO_CHAR(
          ROUND(space_used / space_limit * 100, 1)
          , '990.0')) || '%', 7)                                 AS pct_utilise
      ,CASE WHEN space_used / space_limit * 100 > 90
            THEN '!! CRITIQUE'
            WHEN space_used / space_limit * 100 > 80
            THEN 'Surveiller'
            ELSE 'OK'
       END                                                       AS statut
  FROM v$recovery_file_dest
 WHERE space_limit > 0
;

PROMPT
PROMPT  Repartition espace FRA par type :
PROMPT

-- -----------------------------------------------
-- 3. Detail par type de fichier dans la FRA
-- -----------------------------------------------

COL type_fichier   FORMAT A30  HEAD "Type fichier"
COL pct_espace     FORMAT A8   HEAD "% FRA"
COL pct_recup      FORMAT A10  HEAD "% Recup"
COL nb_fichiers    FORMAT 999  HEAD "Nb"

SELECT file_type                                                 AS type_fichier
      ,LPAD(TRIM(TO_CHAR(percent_space_used, '990.0')) || '%', 7) AS pct_espace
      ,LPAD(TRIM(TO_CHAR(percent_space_reclaimable, '990.0')) || '%', 7) AS pct_recup
      ,number_of_files                                           AS nb_fichiers
  FROM v$recovery_area_usage
 WHERE percent_space_used > 0 OR number_of_files > 0
 ORDER BY percent_space_used DESC
;

PROMPT
PROMPT  Actions :
PROMPT  % Util > 90%      --> Purger archives obsoletes (RMAN DELETE OBSOLETE)
PROMPT  % Recup > 0       --> Espace recuperable par Oracle automatiquement
PROMPT  ORA-19815          --> FRA pleine, augmenter DB_RECOVERY_FILE_DEST_SIZE
PROMPT  ORA-00257          --> Archiver bloque, FRA saturee
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_7
