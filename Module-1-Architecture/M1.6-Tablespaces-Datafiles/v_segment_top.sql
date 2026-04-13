-- ============================================================================
-- SCRIPT     : v_segment_top.sql
-- MODULE     : M1.6 - Tablespaces et Datafiles
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_segment_top.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== TOP SEGMENTS - QUI CONSOMME L'ESPACE ====================
PROMPT
PROMPT  (schemas Oracle internes exclus : SYS, SYSTEM, XDB, CTXSYS...)
PROMPT

-- -----------------------------------------------
-- 1. Top 20 objets par taille
-- -----------------------------------------------

COL rang         FORMAT 99    HEAD "#"
COL proprietaire FORMAT A15   HEAD "Schema"
COL segment      FORMAT A30   HEAD "Objet"
COL type_seg     FORMAT A10   HEAD "Type"
COL tablespace   FORMAT A20   HEAD "Tablespace"
COL taille_mb    FORMAT A12   HEAD "Taille"

SELECT rn                                                        AS rang
      ,owner                                                     AS proprietaire
      ,segment_name                                              AS segment
      ,segment_type                                              AS type_seg
      ,tablespace_name                                           AS tablespace
      ,LPAD(TRIM(TO_CHAR(size_mb, '999,999.0')), 10)            AS taille_mb
  FROM (
    SELECT ROW_NUMBER() OVER (ORDER BY bytes DESC)               AS rn
          ,owner
          ,segment_name
          ,segment_type
          ,tablespace_name
          ,bytes/1048576                                         AS size_mb
      FROM dba_segments
     WHERE owner NOT IN ('SYS','SYSTEM','OUTLN','DBSNMP','XDB',
                          'WMSYS','CTXSYS','MDSYS','ORDDATA','ORDSYS',
                          'APEX_PUBLIC_USER','FLOWS_FILES',
                          'AUDSYS','GSMADMIN_INTERNAL','APPQOSSYS','DBSFWUSER')
       AND owner NOT LIKE 'APEX%'
  )
 WHERE rn <= 20
;

PROMPT
PROMPT  Repartition par type de segment :
PROMPT

-- -----------------------------------------------
-- 2. Espace par type de segment
-- -----------------------------------------------

COL type_seg FORMAT A20  HEAD "Type Segment"
COL nb       FORMAT 999,999 HEAD "Nb"
COL total_mb FORMAT A12  HEAD "Total"
COL pct      FORMAT A8   HEAD "% Total"

SELECT segment_type                                              AS type_seg
      ,COUNT(*)                                                  AS nb
      ,LPAD(TRIM(TO_CHAR(SUM(bytes)/1048576, '999,999')), 10)   AS total_mb
      ,LPAD(TRIM(TO_CHAR(
          ROUND(SUM(bytes) * 100 / (SELECT SUM(bytes) FROM dba_segments), 1)
          , '990.0')) || '%', 7)                                 AS pct
  FROM dba_segments
 GROUP BY segment_type
 ORDER BY SUM(bytes) DESC
 FETCH FIRST 10 ROWS ONLY
;

PROMPT
PROMPT  Espace par schema (top 10) :
PROMPT

-- -----------------------------------------------
-- 3. Espace par schema
-- -----------------------------------------------

COL proprietaire FORMAT A20  HEAD "Schema"
COL nb_objets    FORMAT 999,999 HEAD "Objets"
COL total_mb     FORMAT A12  HEAD "Total"
COL pct          FORMAT A8   HEAD "% Total"

SELECT owner                                                     AS proprietaire
      ,COUNT(*)                                                  AS nb_objets
      ,LPAD(TRIM(TO_CHAR(SUM(bytes)/1048576, '999,999')), 10)   AS total_mb
      ,LPAD(TRIM(TO_CHAR(
          ROUND(SUM(bytes) * 100 / (SELECT SUM(bytes) FROM dba_segments), 1)
          , '990.0')) || '%', 7)                                 AS pct
  FROM dba_segments
 GROUP BY owner
 ORDER BY SUM(bytes) DESC
 FETCH FIRST 10 ROWS ONLY
;

PROMPT
PROMPT  Actions :
PROMPT  Table > 10 GB sans partition   --> Envisager le partitionnement
PROMPT  INDEX > TABLE                  --> Verifier index inutiles (MONITORING USAGE)
PROMPT  LOB > 1 GB                    --> Verifier la retention et le purge
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_6
