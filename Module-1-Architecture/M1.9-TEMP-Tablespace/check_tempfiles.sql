-- ============================================================================
-- SCRIPT     : check_tempfiles.sql
-- MODULE     : M1.9 - TEMP Tablespace
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @check_tempfiles.sql
-- ============================================================================

SET LINESIZE 250
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== TEMP TABLESPACE - DIAGNOSTIC RAPIDE ====================
PROMPT

-- -----------------------------------------------
-- 1. Detail de chaque tempfile (allocation disque + utilisation)
-- -----------------------------------------------

COL tablespace FORMAT A20  HEAD "Tablespace"
COL fichier    FORMAT A65  HEAD "Tempfile"
COL alloue     FORMAT A12  HEAD "Alloue"
COL utilise    FORMAT A12  HEAD "Utilise"
COL libre      FORMAT A12  HEAD "Libre"
COL pct        FORMAT A8   HEAD "% Util"
COL max_mb     FORMAT A12  HEAD "Max (Auto)"
COL pct_max    FORMAT A8   HEAD "% Max"
COL statut     FORMAT A12  HEAD "Statut"

SELECT d.tablespace_name                                         AS tablespace
      ,d.file_name                                               AS fichier
      ,LPAD(TRIM(TO_CHAR(d.bytes/1048576, '999,999')), 10)       AS alloue
      ,LPAD(TRIM(TO_CHAR((d.bytes - h.bytes_free)/1048576, '999,999')), 10) AS utilise
      ,LPAD(TRIM(TO_CHAR(h.bytes_free/1048576, '999,999')), 10)  AS libre
      ,LPAD(TRIM(TO_CHAR(
          ROUND((d.bytes - h.bytes_free) / d.bytes * 100, 1)
          , '990.0')) || '%', 7)                                 AS pct
      ,CASE WHEN d.autoextensible = 'YES'
            THEN LPAD(TRIM(TO_CHAR(d.maxbytes/1073741824, '999.9')) || ' GB', 10)
            ELSE '       NON'
       END                                                       AS max_mb
      ,LPAD(TRIM(TO_CHAR(
          ROUND((d.bytes - h.bytes_free) /
                CASE WHEN d.autoextensible = 'YES' THEN d.maxbytes ELSE d.bytes END * 100, 1)
          , '990.0')) || '%', 7)                                 AS pct_max
      ,CASE
            -- AUTOEXTEND OFF : alerte sur taille actuelle
            WHEN d.autoextensible = 'NO'
                 AND (d.bytes - h.bytes_free) / d.bytes * 100 > 85
            THEN '!! CRITIQUE'
            WHEN d.autoextensible = 'NO'
                 AND (d.bytes - h.bytes_free) / d.bytes * 100 > 70
            THEN 'Surveiller'
            -- AUTOEXTEND ON : alerte sur capacite MAX (le vrai risque)
            WHEN d.autoextensible = 'YES'
                 AND (d.bytes - h.bytes_free) / d.maxbytes * 100 > 85
            THEN '!! CRITIQUE'
            WHEN d.autoextensible = 'YES'
                 AND (d.bytes - h.bytes_free) / d.maxbytes * 100 > 70
            THEN 'Surveiller'
            ELSE 'OK'
       END                                                       AS statut
  FROM dba_temp_files d
  JOIN v$temp_space_header h ON d.file_id = h.file_id
 ORDER BY d.tablespace_name, d.file_id
;

PROMPT
PROMPT  Resume par tablespace TEMP :
PROMPT

-- -----------------------------------------------
-- 2. Resume agrege par tablespace
-- -----------------------------------------------

COL tablespace FORMAT A20  HEAD "Tablespace"
COL nb_files   FORMAT 999  HEAD "Nb"
COL total_mb   FORMAT A12  HEAD "Alloue"
COL utilise_mb FORMAT A12  HEAD "Utilise"
COL libre_mb   FORMAT A12  HEAD "Libre"
COL pct_total  FORMAT A8   HEAD "% Util"
COL max_mb     FORMAT A12  HEAD "Max (Auto)"
COL pct_max_ag FORMAT A8   HEAD "% Max"

SELECT d.tablespace_name                                         AS tablespace
      ,COUNT(*)                                                  AS nb_files
      ,LPAD(TRIM(TO_CHAR(SUM(d.bytes)/1048576, '999,999')), 10)  AS total_mb
      ,LPAD(TRIM(TO_CHAR(SUM(d.bytes - h.bytes_free)/1048576, '999,999')), 10) AS utilise_mb
      ,LPAD(TRIM(TO_CHAR(SUM(h.bytes_free)/1048576, '999,999')), 10) AS libre_mb
      ,LPAD(TRIM(TO_CHAR(
          ROUND(SUM(d.bytes - h.bytes_free) / SUM(d.bytes) * 100, 1)
          , '990.0')) || '%', 7)                                 AS pct_total
      ,LPAD(TRIM(TO_CHAR(SUM(CASE WHEN d.autoextensible = 'YES'
            THEN d.maxbytes ELSE d.bytes END)/1073741824, '999.9')) || ' GB', 10) AS max_mb
      ,LPAD(TRIM(TO_CHAR(
          ROUND(SUM(d.bytes - h.bytes_free) /
                SUM(CASE WHEN d.autoextensible = 'YES'
                    THEN d.maxbytes ELSE d.bytes END) * 100, 1)
          , '990.0')) || '%', 7)                                 AS pct_max_ag
  FROM dba_temp_files d
  JOIN v$temp_space_header h ON d.file_id = h.file_id
 GROUP BY d.tablespace_name
 ORDER BY d.tablespace_name
;

PROMPT
PROMPT  Configuration TEMP :
PROMPT

-- -----------------------------------------------
-- 3. Parametres TEMP critiques
-- -----------------------------------------------

COL information FORMAT A45  HEAD "Information"
COL valeur      FORMAT A45  HEAD "Valeur"

SELECT 'TEMP par defaut de la base'                              AS information
      ,property_value                                            AS valeur
  FROM database_properties
 WHERE property_name = 'DEFAULT_TEMP_TABLESPACE'
UNION ALL
SELECT 'Nombre total de tempfiles'
      ,TRIM(TO_CHAR(COUNT(*), '999'))
  FROM dba_temp_files
UNION ALL
SELECT 'Tablespaces TEMP existants'
      ,TRIM(TO_CHAR(COUNT(*), '999'))
  FROM dba_tablespaces
 WHERE contents = 'TEMPORARY'
UNION ALL
SELECT 'Tempfiles sans AUTOEXTEND'
      ,TRIM(TO_CHAR(COUNT(*), '999'))
       || CASE WHEN COUNT(*) > 0 THEN ' (!! risque ORA-01652)' ELSE ' (OK)' END
  FROM dba_temp_files
 WHERE autoextensible = 'NO'
;

PROMPT
PROMPT  % Util = utilisation de la taille actuelle (allocation disque)
PROMPT  % Max  = utilisation de la capacite MAXIMALE (vrai risque)
PROMPT
PROMPT  % Max > 85% = !! CRITIQUE : capacite max bientot atteinte
PROMPT  % Max > 70% = Surveiller : planifier extension
PROMPT  Max = NON   = pas d'AUTOEXTEND, taille actuelle = taille max
PROMPT  ORA-01652   = TEMP plein, sort/hash/group impossible
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_9
