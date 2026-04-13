-- ============================================================================
-- SCRIPT     : v_datafile_details.sql
-- MODULE     : M1.6 - Tablespaces et Datafiles
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_datafile_details.sql
-- ============================================================================

SET LINESIZE 250
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== DATAFILES - DETAIL PAR TABLESPACE ====================
PROMPT

-- -----------------------------------------------
-- 1. Detail de chaque datafile
-- -----------------------------------------------

COL tablespace FORMAT A20  HEAD "Tablespace"
COL file_id    FORMAT 9999 HEAD "ID"
COL fichier    FORMAT A65  HEAD "Datafile"
COL taille_mb  FORMAT A10  HEAD "Taille"
COL autoext    FORMAT A4   HEAD "Auto"
COL max_mb     FORMAT A10  HEAD "Max"
COL ext_incr   FORMAT A12  HEAD "Increment"
COL statut     FORMAT A10  HEAD "Statut"

SELECT d.tablespace_name                                         AS tablespace
      ,d.file_id
      ,d.file_name                                               AS fichier
      ,LPAD(TRIM(TO_CHAR(d.bytes/1048576, '999,999')), 8)        AS taille_mb
      ,CASE WHEN d.autoextensible = 'YES' THEN 'OUI' ELSE 'NON' END AS autoext
      ,CASE WHEN d.autoextensible = 'YES'
            THEN LPAD(TRIM(TO_CHAR(d.maxbytes/1048576, '999,999')), 8)
            ELSE '     n/a'
       END                                                       AS max_mb
      ,CASE WHEN d.autoextensible = 'YES' AND d.increment_by > 0
            THEN LPAD(TRIM(TO_CHAR(
                d.increment_by * p.block_size / 1048576
                , '99,999')), 8) || ' MB'
            ELSE '     n/a'
       END                                                       AS ext_incr
      ,d.status                                                  AS statut
  FROM dba_data_files d
  CROSS JOIN (SELECT TO_NUMBER(value) AS block_size
                FROM v$parameter
               WHERE name = 'db_block_size') p
 ORDER BY d.tablespace_name, d.file_id
;

PROMPT
PROMPT  Nombre de datafiles par tablespace :
PROMPT

-- -----------------------------------------------
-- 2. Resume par tablespace
-- -----------------------------------------------

COL tablespace FORMAT A20  HEAD "Tablespace"
COL nb_files   FORMAT 999  HEAD "Nb"
COL total_mb   FORMAT A12  HEAD "Total"
COL total_max  FORMAT A12  HEAD "Max Total"

SELECT tablespace_name                                           AS tablespace
      ,COUNT(*)                                                  AS nb_files
      ,LPAD(TRIM(TO_CHAR(SUM(bytes)/1048576, '999,999')), 10)   AS total_mb
      ,LPAD(TRIM(TO_CHAR(SUM(CASE WHEN autoextensible = 'YES'
            THEN maxbytes ELSE bytes END)/1048576, '999,999')), 10) AS total_max
  FROM dba_data_files
 GROUP BY tablespace_name
 ORDER BY SUM(bytes) DESC
;

PROMPT
PROMPT  Actions :
PROMPT  Auto = NON + tablespace > 80%    --> Activer AUTOEXTEND ou ajouter datafile
PROMPT  Taille = Max atteint             --> Augmenter MAXSIZE ou ajouter datafile
PROMPT  Increment trop petit             --> Augmenter pour eviter resizes frequents
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_6
