-- ============================================================================
-- SCRIPT     : check_tablespaces.sql
-- MODULE     : M1.6 - Tablespaces et Datafiles
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @check_tablespaces.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== TABLESPACES - DIAGNOSTIC RAPIDE ====================
PROMPT

-- -----------------------------------------------
-- 1. Espace par tablespace (permanent + undo)
-- -----------------------------------------------

COL tablespace FORMAT A20  HEAD "Tablespace"
COL type_ts    FORMAT A10  HEAD "Type"
COL taille_mb  FORMAT A12  HEAD "Taille"
COL utilise_mb FORMAT A12  HEAD "Utilise"
COL libre_mb   FORMAT A12  HEAD "Libre"
COL pct        FORMAT A8   HEAD "% Util"
COL max_mb     FORMAT A12  HEAD "Max (Auto)"
COL pct_max    FORMAT A8   HEAD "% Max"
COL statut     FORMAT A12  HEAD "Statut"

WITH ts_size AS (
    SELECT tablespace_name
          ,SUM(bytes) AS total_bytes
          ,SUM(CASE WHEN autoextensible = 'YES'
                    THEN maxbytes ELSE bytes END) AS max_bytes
          ,CASE WHEN SUM(CASE WHEN autoextensible = 'YES' THEN 1 ELSE 0 END) > 0
                THEN 'Y' ELSE 'N' END AS has_autoext
      FROM dba_data_files
     GROUP BY tablespace_name
),
ts_free AS (
    SELECT tablespace_name
          ,SUM(bytes) AS free_bytes
      FROM dba_free_space
     GROUP BY tablespace_name
)
SELECT t.tablespace_name                                         AS tablespace
      ,t.contents                                                AS type_ts
      ,LPAD(TRIM(TO_CHAR(s.total_bytes/1048576, '999,999')), 10) AS taille_mb
      ,LPAD(TRIM(TO_CHAR((s.total_bytes - NVL(f.free_bytes,0))/1048576, '999,999')), 10) AS utilise_mb
      ,LPAD(TRIM(TO_CHAR(NVL(f.free_bytes,0)/1048576, '999,999')), 10) AS libre_mb
      ,LPAD(TRIM(TO_CHAR(
          ROUND((s.total_bytes - NVL(f.free_bytes,0)) / s.total_bytes * 100, 1)
          , '990.0')) || '%', 7)                                 AS pct
      ,CASE WHEN s.has_autoext = 'Y'
            THEN LPAD(TRIM(TO_CHAR(s.max_bytes/1073741824, '999.9')) || ' GB', 10)
            ELSE '       NON'
       END                                                       AS max_mb
      ,LPAD(TRIM(TO_CHAR(
          ROUND((s.total_bytes - NVL(f.free_bytes,0)) / s.max_bytes * 100, 1)
          , '990.0')) || '%', 7)                                 AS pct_max
      ,CASE
            -- AUTOEXTEND OFF : alerte sur taille actuelle
            WHEN s.has_autoext = 'N'
                 AND (s.total_bytes - NVL(f.free_bytes,0)) / s.total_bytes * 100 > 85
            THEN '!! CRITIQUE'
            WHEN s.has_autoext = 'N'
                 AND (s.total_bytes - NVL(f.free_bytes,0)) / s.total_bytes * 100 > 70
            THEN 'Surveiller'
            -- AUTOEXTEND ON : alerte sur capacite MAX
            WHEN s.has_autoext = 'Y'
                 AND (s.total_bytes - NVL(f.free_bytes,0)) / s.max_bytes * 100 > 85
            THEN '!! CRITIQUE'
            WHEN s.has_autoext = 'Y'
                 AND (s.total_bytes - NVL(f.free_bytes,0)) / s.max_bytes * 100 > 70
            THEN 'Surveiller'
            ELSE 'OK'
       END                                                       AS statut
  FROM dba_tablespaces t
  JOIN ts_size s ON t.tablespace_name = s.tablespace_name
  LEFT JOIN ts_free f ON t.tablespace_name = f.tablespace_name
 WHERE t.contents != 'TEMPORARY'
 ORDER BY (s.total_bytes - NVL(f.free_bytes,0)) / s.max_bytes DESC
;

PROMPT
PROMPT  Tablespaces temporaires :
PROMPT

-- -----------------------------------------------
-- 2. Tablespace TEMP (allocation disque + tris actifs)
-- -----------------------------------------------

COL tablespace FORMAT A20  HEAD "Tablespace"
COL type_ts    FORMAT A10  HEAD "Type"
COL taille_mb  FORMAT A12  HEAD "Alloue"
COL utilise_mb FORMAT A12  HEAD "Tris actifs"
COL libre_mb   FORMAT A12  HEAD "Libre tris"
COL pct        FORMAT A8   HEAD "% Tris"
COL max_mb     FORMAT A12  HEAD "Max (Auto)"
COL pct_max    FORMAT A8   HEAD "% Max"
COL statut     FORMAT A12  HEAD "Statut"

SELECT t.tablespace_name                                         AS tablespace
      ,'TEMPORARY'                                               AS type_ts
      ,LPAD(TRIM(TO_CHAR(SUM(d.bytes)/1048576, '999,999')), 10) AS taille_mb
      ,LPAD(TRIM(TO_CHAR(tf.allocated_space/1048576, '999,999')), 10) AS utilise_mb
      ,LPAD(TRIM(TO_CHAR(tf.free_space/1048576, '999,999')), 10) AS libre_mb
      ,LPAD(TRIM(TO_CHAR(
          ROUND(tf.allocated_space / SUM(d.bytes) * 100, 1)
          , '990.0')) || '%', 7)                                 AS pct
      ,CASE WHEN SUM(CASE WHEN d.autoextensible = 'YES' THEN 1 ELSE 0 END) > 0
            THEN LPAD(TRIM(TO_CHAR(SUM(CASE WHEN d.autoextensible = 'YES'
                  THEN d.maxbytes ELSE d.bytes END)/1073741824, '999.9')) || ' GB', 10)
            ELSE '       NON'
       END                                                       AS max_mb
      ,LPAD(TRIM(TO_CHAR(
          ROUND(SUM(d.bytes) /
                SUM(CASE WHEN d.autoextensible = 'YES'
                    THEN d.maxbytes ELSE d.bytes END) * 100, 1)
          , '990.0')) || '%', 7)                                 AS pct_max
      ,CASE
            WHEN SUM(d.bytes) /
                 SUM(CASE WHEN d.autoextensible = 'YES'
                     THEN d.maxbytes ELSE d.bytes END) * 100 > 85
            THEN '!! CRITIQUE'
            WHEN SUM(d.bytes) /
                 SUM(CASE WHEN d.autoextensible = 'YES'
                     THEN d.maxbytes ELSE d.bytes END) * 100 > 70
            THEN 'Surveiller'
            ELSE 'OK'
       END                                                       AS statut
  FROM dba_tablespaces t
  JOIN dba_temp_files d ON t.tablespace_name = d.tablespace_name
  JOIN dba_temp_free_space tf ON t.tablespace_name = tf.tablespace_name
 WHERE t.contents = 'TEMPORARY'
 GROUP BY t.tablespace_name, tf.free_space, tf.allocated_space
;

PROMPT
PROMPT  Resume tablespaces :
PROMPT

-- -----------------------------------------------
-- 3. Resume global
-- -----------------------------------------------

COL information FORMAT A35  HEAD "Information"
COL valeur      FORMAT A20  HEAD "Valeur"

SELECT 'Tablespaces permanents'                                  AS information
      ,TRIM(TO_CHAR(COUNT(*), '999'))                            AS valeur
  FROM dba_tablespaces WHERE contents = 'PERMANENT'
UNION ALL
SELECT 'Tablespaces temporaires'
      ,TRIM(TO_CHAR(COUNT(*), '999'))
  FROM dba_tablespaces WHERE contents = 'TEMPORARY'
UNION ALL
SELECT 'Tablespaces UNDO'
      ,TRIM(TO_CHAR(COUNT(*), '999'))
  FROM dba_tablespaces WHERE contents = 'UNDO'
UNION ALL
SELECT 'Total fichiers (data + temp)'
      ,TRIM(TO_CHAR(
          (SELECT COUNT(*) FROM dba_data_files) +
          (SELECT COUNT(*) FROM dba_temp_files)
          , '999'))
  FROM dual
UNION ALL
SELECT 'Espace total alloue (data + temp)'
      ,TRIM(TO_CHAR(
          ( (SELECT SUM(bytes) FROM dba_data_files)
          + (SELECT NVL(SUM(bytes),0) FROM dba_temp_files)
          ) / 1073741824, '999.9')) || ' GB'
  FROM dual
;

PROMPT
PROMPT  % Util = utilisation de la taille actuelle
PROMPT  % Max  = utilisation de la capacite MAXIMALE (le vrai risque)
PROMPT
PROMPT  % Max > 85% = !! CRITIQUE : capacite max bientot atteinte
PROMPT  % Max > 70% = Surveiller  : planifier extension ou ajout datafile
PROMPT  Max = NON   = pas d'AUTOEXTEND, taille actuelle = taille max
PROMPT  ORA-01653   = tablespace plein, aucune extension possible
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_6
