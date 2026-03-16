-- ============================================================================
-- SCRIPT     : check_memory.sql
-- MODULE     : M1.4 - Memoire Oracle : SGA et PGA
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @check_memory.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== MEMOIRE ORACLE - DIAGNOSTIC RAPIDE ====================
PROMPT

-- -----------------------------------------------
-- 1. Repartition memoire globale
-- -----------------------------------------------

COL composant FORMAT A30 HEAD "Composant"
COL taille    FORMAT A12 HEAD "Taille"
COL detail    FORMAT A50 HEAD "Detail"

WITH mem_raw AS (
  SELECT (SELECT SUM(value) FROM v$sga) AS sga_bytes,
         (SELECT value FROM v$pgastat WHERE name = 'total PGA allocated') AS pga_bytes,
         (SELECT COUNT(*) FROM v$session WHERE type = 'USER') AS user_sessions,
         (SELECT COUNT(*) FROM v$session WHERE type = 'USER' AND status = 'ACTIVE') AS active_sessions
  FROM dual
)
SELECT composant, taille, detail
FROM (
  SELECT 1 AS tri,
         'SGA (Memoire partagee)' AS composant,
         CASE
           WHEN sga_bytes/1048576 >= 1024
             THEN LPAD(TRIM(TO_CHAR(ROUND(sga_bytes/1073741824, 1), '999.0')) || ' GB', 12)
           ELSE LPAD(TRIM(TO_CHAR(ROUND(sga_bytes/1048576), '999,999')) || ' MB', 12)
         END AS taille,
         'Parametre : SGA_TARGET' AS detail
  FROM mem_raw
  UNION ALL
  SELECT 2,
         'PGA (Memoire privee)',
         CASE
           WHEN pga_bytes/1048576 >= 1024
             THEN LPAD(TRIM(TO_CHAR(ROUND(pga_bytes/1073741824, 1), '999.0')) || ' GB', 12)
           ELSE LPAD(TRIM(TO_CHAR(ROUND(pga_bytes/1048576), '999,999')) || ' MB', 12)
         END,
         'Parametre : PGA_AGGREGATE_TARGET'
  FROM mem_raw
  UNION ALL
  SELECT 3,
         '--- TOTAL MEMOIRE ---',
         CASE
           WHEN (sga_bytes + pga_bytes)/1048576 >= 1024
             THEN LPAD(TRIM(TO_CHAR(ROUND((sga_bytes + pga_bytes)/1073741824, 1), '999.0')) || ' GB', 12)
           ELSE LPAD(TRIM(TO_CHAR(ROUND((sga_bytes + pga_bytes)/1048576), '999,999')) || ' MB', 12)
         END,
         TO_CHAR(user_sessions) || ' sessions (' || TO_CHAR(active_sessions) || ' actives)'
  FROM mem_raw
)
ORDER BY tri;

-- -----------------------------------------------
-- 2. Composants SGA principaux
-- -----------------------------------------------

PROMPT
PROMPT  Composants SGA principaux :
PROMPT

COL composant_sga FORMAT A30 HEAD "Composant SGA"
COL taille_mb     FORMAT A12 HEAD "Taille"
COL pct           FORMAT A8  HEAD "% SGA"

SELECT composant_sga, taille_mb, pct
FROM (
  SELECT 1 AS tri,
         'Buffer Cache (donnees)' AS composant_sga,
         CASE
           WHEN current_size/1048576 >= 1024
             THEN LPAD(TRIM(TO_CHAR(ROUND(current_size/1073741824, 1), '999.0')) || ' GB', 12)
           ELSE LPAD(TRIM(TO_CHAR(ROUND(current_size/1048576), '999,999')) || ' MB', 12)
         END AS taille_mb,
         LPAD(TO_CHAR(ROUND(current_size * 100 /
           NULLIF((SELECT SUM(current_size) FROM v$sga_dynamic_components), 0)), '999') || '%', 8) AS pct
  FROM   v$sga_dynamic_components
  WHERE  component = 'DEFAULT buffer cache'
  UNION ALL
  SELECT 2,
         'Shared Pool (SQL/metadata)',
         CASE
           WHEN current_size/1048576 >= 1024
             THEN LPAD(TRIM(TO_CHAR(ROUND(current_size/1073741824, 1), '999.0')) || ' GB', 12)
           ELSE LPAD(TRIM(TO_CHAR(ROUND(current_size/1048576), '999,999')) || ' MB', 12)
         END,
         LPAD(TO_CHAR(ROUND(current_size * 100 /
           NULLIF((SELECT SUM(current_size) FROM v$sga_dynamic_components), 0)), '999') || '%', 8)
  FROM   v$sga_dynamic_components
  WHERE  component = 'shared pool'
  UNION ALL
  SELECT 3,
         'Large Pool',
         CASE
           WHEN current_size/1048576 >= 1024
             THEN LPAD(TRIM(TO_CHAR(ROUND(current_size/1073741824, 1), '999.0')) || ' GB', 12)
           ELSE LPAD(TRIM(TO_CHAR(ROUND(current_size/1048576), '999,999')) || ' MB', 12)
         END,
         LPAD(TO_CHAR(ROUND(current_size * 100 /
           NULLIF((SELECT SUM(current_size) FROM v$sga_dynamic_components), 0)), '999') || '%', 8)
  FROM   v$sga_dynamic_components
  WHERE  component = 'large pool'
  UNION ALL
  SELECT 4,
         'Redo Log Buffer',
         CASE
           WHEN bytes/1048576 >= 1024
             THEN LPAD(TRIM(TO_CHAR(ROUND(bytes/1073741824, 1), '999.0')) || ' GB', 12)
           ELSE LPAD(TRIM(TO_CHAR(ROUND(bytes/1048576), '999,999')) || ' MB', 12)
         END,
         ' '
  FROM   v$sgastat
  WHERE  name = 'log_buffer'
)
ORDER BY tri;

-- -----------------------------------------------
-- 3. Sante PGA (risque ORA-04030)
-- -----------------------------------------------

PROMPT
PROMPT  Sante PGA (risque ORA-04030) :
PROMPT

COL indicateur FORMAT A35 HEAD "Indicateur"
COL valeur     FORMAT A15 HEAD "Valeur"
COL statut     FORMAT A25 HEAD "Statut"

WITH pga_info AS (
  SELECT (SELECT value FROM v$pgastat WHERE name = 'aggregate PGA target parameter') AS target_bytes,
         (SELECT value FROM v$pgastat WHERE name = 'total PGA allocated') AS alloc_bytes,
         (SELECT value FROM v$pgastat WHERE name = 'maximum PGA allocated') AS max_bytes,
         (SELECT value FROM v$pgastat WHERE name = 'over allocation count') AS over_alloc,
         (SELECT COUNT(*) FROM v$session WHERE type = 'USER') AS user_sessions
  FROM dual
)
SELECT indicateur, valeur, statut
FROM (
  SELECT 1 AS tri,
         'PGA cible (target)' AS indicateur,
         CASE WHEN target_bytes/1048576 >= 1024
              THEN LPAD(TRIM(TO_CHAR(ROUND(target_bytes/1073741824, 1), '999.0')) || ' GB', 15)
              ELSE LPAD(TRIM(TO_CHAR(ROUND(target_bytes/1048576), '999,999')) || ' MB', 15)
         END AS valeur,
         ' ' AS statut
  FROM pga_info
  UNION ALL
  SELECT 2,
         'PGA allouee actuellement',
         CASE WHEN alloc_bytes/1048576 >= 1024
              THEN LPAD(TRIM(TO_CHAR(ROUND(alloc_bytes/1073741824, 1), '999.0')) || ' GB', 15)
              ELSE LPAD(TRIM(TO_CHAR(ROUND(alloc_bytes/1048576), '999,999')) || ' MB', 15)
         END,
         CASE
           WHEN alloc_bytes > target_bytes * 0.9 THEN '!! SATURATION > 90%'
           WHEN alloc_bytes > target_bytes * 0.7 THEN '! Attention > 70%'
           ELSE 'OK'
         END
  FROM pga_info
  UNION ALL
  SELECT 3,
         'PGA max atteinte',
         CASE WHEN max_bytes/1048576 >= 1024
              THEN LPAD(TRIM(TO_CHAR(ROUND(max_bytes/1073741824, 1), '999.0')) || ' GB', 15)
              ELSE LPAD(TRIM(TO_CHAR(ROUND(max_bytes/1048576), '999,999')) || ' MB', 15)
         END,
         ' '
  FROM pga_info
  UNION ALL
  SELECT 4,
         'Over allocation count',
         LPAD(TRIM(TO_CHAR(over_alloc, '999,999')), 15),
         CASE
           WHEN over_alloc > 0 THEN '!! ORA-04030 probable'
           ELSE 'OK (aucun depassement)'
         END
  FROM pga_info
  UNION ALL
  SELECT 5,
         'PGA moyenne par session',
         LPAD(TRIM(TO_CHAR(
           ROUND(alloc_bytes / NULLIF(user_sessions, 0) / 1048576, 1),
           '999,999.0')) || ' MB', 15),
         CASE
           WHEN alloc_bytes / NULLIF(user_sessions, 0) / 1048576 < 5
             THEN '! < 5 MB/session (risque)'
           ELSE 'OK'
         END
  FROM pga_info
)
ORDER BY tri;

-- -----------------------------------------------
-- 4. Regles de sizing
-- -----------------------------------------------

PROMPT
PROMPT  Regles de sizing (rappel) :
PROMPT  SGA recommandee  = 50% RAM serveur
PROMPT  PGA recommandee  = 20-25% RAM serveur
PROMPT  SGA + PGA        < 80% RAM serveur (laisser place a l'OS)
PROMPT
PROMPT  ORA-04030 = PGA saturee --> Augmenter PGA_AGGREGATE_TARGET
PROMPT  I/O excessifs = SGA trop petite --> Augmenter SGA_TARGET
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_4
