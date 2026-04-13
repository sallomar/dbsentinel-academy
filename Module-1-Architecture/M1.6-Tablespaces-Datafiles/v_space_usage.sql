-- ============================================================================
-- SCRIPT     : v_space_usage.sql
-- MODULE     : M1.6 - Tablespaces et Datafiles
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_space_usage.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== ESPACE TABLESPACES - CAPACITE MAXIMALE ====================
PROMPT

-- -----------------------------------------------
-- 1. Espace actuel vs capacite max (AUTOEXTEND)
-- -----------------------------------------------

COL tablespace FORMAT A20  HEAD "Tablespace"
COL taille_mb  FORMAT A12  HEAD "Actuel"
COL utilise_mb FORMAT A12  HEAD "Utilise"
COL libre_mb   FORMAT A12  HEAD "Libre"
COL pct_actuel FORMAT A8   HEAD "% Util"
COL max_mb     FORMAT A12  HEAD "Max (Auto)"
COL marge_mb   FORMAT A12  HEAD "Marge"
COL autoext    FORMAT A8   HEAD "AutoExt"

WITH df AS (
    SELECT tablespace_name
          ,SUM(bytes)/1048576                                    AS current_mb
          ,SUM(CASE WHEN autoextensible = 'YES'
                    THEN maxbytes ELSE bytes END)/1048576        AS max_mb
          ,CASE WHEN SUM(CASE WHEN autoextensible = 'YES' THEN 1 ELSE 0 END) > 0
                THEN 'OUI' ELSE 'NON' END                       AS has_autoext
      FROM dba_data_files
     GROUP BY tablespace_name
),
fs AS (
    SELECT tablespace_name
          ,SUM(bytes)/1048576                                    AS free_mb
      FROM dba_free_space
     GROUP BY tablespace_name
)
SELECT df.tablespace_name                                        AS tablespace
      ,LPAD(TRIM(TO_CHAR(df.current_mb, '999,999')), 10)        AS taille_mb
      ,LPAD(TRIM(TO_CHAR(df.current_mb - NVL(fs.free_mb,0), '999,999')), 10) AS utilise_mb
      ,LPAD(TRIM(TO_CHAR(NVL(fs.free_mb,0), '999,999')), 10)   AS libre_mb
      ,LPAD(TRIM(TO_CHAR(
          ROUND((df.current_mb - NVL(fs.free_mb,0)) / df.current_mb * 100, 1)
          , '990.0')) || '%', 7)                                 AS pct_actuel
      ,LPAD(TRIM(TO_CHAR(df.max_mb, '999,999')), 10)            AS max_mb
      ,LPAD(TRIM(TO_CHAR(df.max_mb - (df.current_mb - NVL(fs.free_mb,0)), '999,999')), 10) AS marge_mb
      ,df.has_autoext                                            AS autoext
  FROM df
  LEFT JOIN fs ON df.tablespace_name = fs.tablespace_name
 ORDER BY (df.current_mb - NVL(fs.free_mb,0)) / df.current_mb DESC
;

PROMPT
PROMPT  Datafiles sans AUTOEXTEND (risque ORA-01653) :
PROMPT

-- -----------------------------------------------
-- 2. Datafiles sans AUTOEXTEND
-- -----------------------------------------------

COL tablespace FORMAT A20  HEAD "Tablespace"
COL fichier    FORMAT A55  HEAD "Datafile"
COL taille_mb  FORMAT A10  HEAD "Taille"

SELECT tablespace_name                                           AS tablespace
      ,file_name                                                 AS fichier
      ,LPAD(TRIM(TO_CHAR(bytes/1048576, '999,999')), 8)          AS taille_mb
  FROM dba_data_files
 WHERE autoextensible = 'NO'
 ORDER BY tablespace_name, file_id
;

PROMPT
PROMPT  Actions :
PROMPT  % Util > 85%                --> Etendre le tablespace (ajouter datafile)
PROMPT  AutoExt = NON               --> Risque ORA-01653 si tablespace plein
PROMPT  Marge < 500 MB              --> Planifier extension rapidement
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_6
