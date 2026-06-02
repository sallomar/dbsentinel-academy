-- ============================================================================
-- SCRIPT     : v_temp_sessions.sql
-- MODULE     : M1.9 - TEMP Tablespace
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_temp_sessions.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== TEMP - SESSIONS CONSOMMATRICES ====================
PROMPT
PROMPT  Note : sections vides = aucune session n'utilise actuellement le TEMP
PROMPT

-- -----------------------------------------------
-- 1. Top 15 sessions actives utilisant le TEMP
-- -----------------------------------------------

COL sid_serial FORMAT A14   HEAD "SID,Serial"
COL utilisateur FORMAT A15  HEAD "Utilisateur"
COL programme  FORMAT A22   HEAD "Programme"
COL tablespace FORMAT A18   HEAD "Tablespace TEMP"
COL type_seg   FORMAT A10   HEAD "Type"
COL taille_mb  FORMAT A12   HEAD "Taille TEMP"
COL sql_id     FORMAT A14   HEAD "SQL_ID"

SELECT TRIM(TO_CHAR(s.sid)) || ',' || TRIM(TO_CHAR(s.serial#))   AS sid_serial
      ,NVL(s.username, 'BACKGROUND')                             AS utilisateur
      ,SUBSTR(NVL(s.program, '-'), 1, 22)                        AS programme
      ,u.tablespace                                              AS tablespace
      ,u.segtype                                                 AS type_seg
      ,LPAD(TRIM(TO_CHAR(u.blocks * 8 / 1024, '999,999.0')) || ' MB', 12) AS taille_mb
      ,NVL(s.sql_id, '-')                                        AS sql_id
  FROM v$tempseg_usage u
  JOIN v$session s ON u.session_addr = s.saddr
 ORDER BY u.blocks DESC
 FETCH FIRST 15 ROWS ONLY
;

PROMPT
PROMPT  Resume par utilisateur :
PROMPT

-- -----------------------------------------------
-- 2. Agregation TEMP par utilisateur
-- -----------------------------------------------

COL utilisateur FORMAT A20  HEAD "Utilisateur"
COL nb_sessions FORMAT 999  HEAD "Sessions"
COL nb_segments FORMAT 999  HEAD "Segments"
COL total_mb    FORMAT A14  HEAD "Total TEMP"
COL pct_temp    FORMAT A8   HEAD "% TEMP"

SELECT NVL(s.username, 'BACKGROUND')                             AS utilisateur
      ,COUNT(DISTINCT s.sid)                                     AS nb_sessions
      ,COUNT(*)                                                  AS nb_segments
      ,LPAD(TRIM(TO_CHAR(SUM(u.blocks) * 8 / 1024, '999,999')) || ' MB', 12) AS total_mb
      ,LPAD(TRIM(TO_CHAR(
          ROUND(SUM(u.blocks) * 100 /
                NULLIF(SUM(SUM(u.blocks)) OVER (), 0), 1)
          , '990.0')) || '%', 7)                                 AS pct_temp
  FROM v$tempseg_usage u
  JOIN v$session s ON u.session_addr = s.saddr
 GROUP BY s.username
 ORDER BY SUM(u.blocks) DESC
;

PROMPT
PROMPT  Repartition par type d'operation :
PROMPT

-- -----------------------------------------------
-- 3. Repartition par type de segment temp
-- -----------------------------------------------

COL type_seg     FORMAT A15  HEAD "Type Operation"
COL nb_segments  FORMAT 999  HEAD "Nb"
COL total_mb     FORMAT A14  HEAD "Total"
COL pct          FORMAT A8   HEAD "% TEMP"
COL description  FORMAT A40  HEAD "Description"

SELECT u.segtype                                                 AS type_seg
      ,COUNT(*)                                                  AS nb_segments
      ,LPAD(TRIM(TO_CHAR(SUM(u.blocks) * 8 / 1024, '999,999')) || ' MB', 12) AS total_mb
      ,LPAD(TRIM(TO_CHAR(
          ROUND(SUM(u.blocks) * 100 /
                NULLIF(SUM(SUM(u.blocks)) OVER (), 0), 1)
          , '990.0')) || '%', 7)                                 AS pct
      ,CASE u.segtype
            WHEN 'SORT'  THEN 'ORDER BY, GROUP BY, DISTINCT'
            WHEN 'HASH'  THEN 'Hash Join, GROUP BY (HASH)'
            WHEN 'DATA'  THEN 'Tables temporaires (GTT)'
            WHEN 'INDEX' THEN 'CREATE INDEX, REBUILD'
            WHEN 'LOB_DATA' THEN 'Manipulation LOB'
            ELSE 'Autre type'
       END                                                       AS description
  FROM v$tempseg_usage u
 GROUP BY u.segtype
 ORDER BY SUM(u.blocks) DESC
;

PROMPT
PROMPT  Actions :
PROMPT  Session > 1 GB TEMP   --> Verifier le SQL_ID (requete a optimiser)
PROMPT  Type SORT majoritaire --> Verifier index manquants (eviter ORDER BY)
PROMPT  Type HASH majoritaire --> PGA trop petite (overflow tris)
PROMPT  Type DATA important   --> Tables temporaires globales utilisees intensivement
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_9
