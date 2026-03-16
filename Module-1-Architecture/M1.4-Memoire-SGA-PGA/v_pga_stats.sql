-- ============================================================================
-- SCRIPT     : v_pga_stats.sql
-- MODULE     : M1.4 - Memoire Oracle : SGA et PGA
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_pga_stats.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== PGA - ANALYSE DETAILLEE ====================
PROMPT

-- -----------------------------------------------
-- 1. Statistiques PGA globales (V$PGASTAT)
-- -----------------------------------------------

COL indicateur FORMAT A40 HEAD "Indicateur PGA"
COL valeur     FORMAT A15 HEAD "Valeur"

SELECT name AS indicateur,
       CASE
         WHEN unit = 'bytes' AND value >= 1073741824
           THEN LPAD(TRIM(TO_CHAR(ROUND(value/1073741824, 1), '999,999.0')) || ' GB', 15)
         WHEN unit = 'bytes'
           THEN LPAD(TRIM(TO_CHAR(ROUND(value/1048576), '999,999')) || ' MB', 15)
         WHEN unit = 'percent'
           THEN LPAD(TRIM(TO_CHAR(value, '999,999')) || ' %', 15)
         ELSE LPAD(TRIM(TO_CHAR(value, '999,999,999')), 15)
       END AS valeur
FROM   v$pgastat
WHERE  name IN (
  'aggregate PGA target parameter',
  'aggregate PGA auto target',
  'total PGA allocated',
  'total PGA inuse',
  'maximum PGA allocated',
  'total freeable PGA memory',
  'over allocation count',
  'cache hit percentage'
);

-- -----------------------------------------------
-- 2. Workareas : multipass = PGA trop petite
-- -----------------------------------------------

PROMPT
PROMPT  Efficacite Workareas (tri, jointures, hash) :
PROMPT

COL type_exec   FORMAT A20 HEAD "Type execution"
COL nb          FORMAT 999,999,999 HEAD "Nb"
COL diagnostic  FORMAT A40 HEAD "Diagnostic"

SELECT 'Total optimal' AS type_exec,
       SUM(optimal_executions) AS nb,
       'Executions 100% memoire (bon)' AS diagnostic
FROM   v$sql_workarea_histogram
UNION ALL
SELECT 'Total onepass (temp)',
       SUM(onepass_executions),
       CASE
         WHEN SUM(onepass_executions) > 0 THEN '! Debordement temp disk'
         ELSE 'OK'
       END
FROM   v$sql_workarea_histogram
UNION ALL
SELECT 'Total multipass (lent)',
       SUM(multipasses_executions),
       CASE
         WHEN SUM(multipasses_executions) > 0 THEN '!! PGA trop petite - AUGMENTER'
         ELSE 'OK (aucun multipass)'
       END
FROM   v$sql_workarea_histogram;

-- -----------------------------------------------
-- 3. Top 10 sessions par consommation PGA
-- -----------------------------------------------

PROMPT
PROMPT  Top 10 sessions par PGA (memoire privee) :
PROMPT

COL sid_serial FORMAT A12  HEAD "SID,Serial"
COL username   FORMAT A15  HEAD "Utilisateur"
COL program    FORMAT A25  HEAD "Programme"
COL pga_mb     FORMAT A10  HEAD "PGA (MB)"
COL statut     FORMAT A8   HEAD "Statut"

SELECT sid_serial, username, program, pga_mb, statut
FROM (
  SELECT s.sid || ',' || s.serial# AS sid_serial,
         NVL(s.username, 'SYS (bg)') AS username,
         SUBSTR(NVL(s.program, '-'), 1, 25) AS program,
         LPAD(TRIM(TO_CHAR(ROUND(p.pga_used_mem/1048576, 1), '99,999.0')), 10) AS pga_mb,
         s.status AS statut,
         ROW_NUMBER() OVER (ORDER BY p.pga_used_mem DESC) AS rn
  FROM   v$session s
  JOIN   v$process p ON p.addr = s.paddr
  WHERE  s.type = 'USER'
)
WHERE rn <= 10;

-- -----------------------------------------------
-- 4. PGA Target Advice (V$PGA_TARGET_ADVICE)
-- -----------------------------------------------

PROMPT
PROMPT  Conseil Oracle (V$PGA_TARGET_ADVICE) :
PROMPT

COL pga_cible  FORMAT A12 HEAD "PGA cible"
COL facteur    FORMAT A10 HEAD "Factor"
COL hit_pct    FORMAT A10 HEAD "Cache %"
COL overalloc  FORMAT 999,999 HEAD "OverAlloc"
COL conseil    FORMAT A25 HEAD "Conseil"

SELECT CASE
         WHEN pga_target_for_estimate/1048576 >= 1024
           THEN LPAD(TRIM(TO_CHAR(ROUND(pga_target_for_estimate/1073741824, 1), '999.0')) || ' GB', 12)
         ELSE LPAD(TRIM(TO_CHAR(ROUND(pga_target_for_estimate/1048576), '999,999')) || ' MB', 12)
       END AS pga_cible,
       LPAD(TO_CHAR(pga_target_factor, '0.99'), 10) AS facteur,
       LPAD(TO_CHAR(ROUND(estd_pga_cache_hit_percentage), '999') || '%', 10) AS hit_pct,
       estd_overalloc_count AS overalloc,
       CASE
         WHEN pga_target_factor = 1 THEN '--> CONFIG ACTUELLE'
         WHEN estd_overalloc_count > 0 THEN '!! Risque ORA-04030'
         WHEN estd_pga_cache_hit_percentage < 80 THEN 'Cache faible'
         ELSE ' '
       END AS conseil
FROM   v$pga_target_advice
WHERE  pga_target_factor BETWEEN 0.25 AND 2
ORDER BY pga_target_for_estimate;

PROMPT
PROMPT  Actions :
PROMPT  Over allocation count > 0   --> Augmenter PGA_AGGREGATE_TARGET
PROMPT  Multipass executions > 0    --> PGA trop petite pour les tris/jointures
PROMPT  Cache hit % < 80%           --> PGA sous-dimensionnee
PROMPT  Top session > 500 MB        --> Verifier requete gourmande
PROMPT
PROMPT =====================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_4
