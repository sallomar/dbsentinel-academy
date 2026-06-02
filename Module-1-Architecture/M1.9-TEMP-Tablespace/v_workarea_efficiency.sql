-- ============================================================================
-- SCRIPT     : v_workarea_efficiency.sql
-- MODULE     : M1.9 - TEMP Tablespace
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_workarea_efficiency.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== WORKAREA - EFFICACITE TRIS / HASH ====================
PROMPT

-- -----------------------------------------------
-- 1. Synthese globale efficacite workarea
-- -----------------------------------------------

COL metrique     FORMAT A40  HEAD "Metrique"
COL valeur_calc  FORMAT A30  HEAD "Valeur"
COL diagnostic   FORMAT A40  HEAD "Diagnostic"

SELECT 'Total executions optimal (en memoire)'                   AS metrique
      ,LPAD(TRIM(TO_CHAR(SUM(optimal_executions), '999,999,999')), 16) AS valeur_calc
      ,CASE WHEN SUM(optimal_executions) * 100 /
                 NULLIF(SUM(optimal_executions + onepass_executions
                            + multipasses_executions), 0) > 95
            THEN 'OK : > 95% en memoire'
            ELSE 'A AMELIORER : trop d''overflow TEMP'
       END                                                       AS diagnostic
  FROM v$sql_workarea_histogram
UNION ALL
SELECT 'Total executions onepass (overflow TEMP)'
      ,LPAD(TRIM(TO_CHAR(SUM(onepass_executions), '999,999,999')), 16)
      ,CASE WHEN SUM(onepass_executions) = 0
            THEN 'OK : aucun overflow'
            ELSE 'INFO : ' || TRIM(TO_CHAR(ROUND(SUM(onepass_executions) * 100 /
                 NULLIF(SUM(optimal_executions + onepass_executions
                            + multipasses_executions), 0), 2))) || '% overflow disque'
       END
  FROM v$sql_workarea_histogram
UNION ALL
SELECT 'Total executions multipass (LENT)'
      ,LPAD(TRIM(TO_CHAR(SUM(multipasses_executions), '999,999,999')), 16)
      ,CASE WHEN SUM(multipasses_executions) = 0
            THEN 'OK : aucun multipass'
            ELSE '!! ALERTE : PGA tres sous-dimensionnee'
       END
  FROM v$sql_workarea_histogram
;

PROMPT
PROMPT  Histogramme par taille de workarea :
PROMPT

-- -----------------------------------------------
-- 2. Histogramme efficacite par taille
-- -----------------------------------------------

COL plage_lo    FORMAT A14   HEAD "Plage min"
COL plage_hi    FORMAT A14   HEAD "Plage max"
COL nb_optimal  FORMAT A12   HEAD "Optimal"
COL nb_onepass  FORMAT A12   HEAD "Onepass"
COL nb_multi    FORMAT A12   HEAD "Multipass"
COL pct_overflow FORMAT A10  HEAD "% Overflow"

SELECT LPAD(TRIM(TO_CHAR(low_optimal_size/1024, '999,999')) || ' KB', 12) AS plage_lo
      ,LPAD(TRIM(TO_CHAR(high_optimal_size/1024, '999,999')) || ' KB', 12) AS plage_hi
      ,LPAD(TRIM(TO_CHAR(optimal_executions, '999,999,999')), 10) AS nb_optimal
      ,LPAD(TRIM(TO_CHAR(onepass_executions, '999,999,999')), 10) AS nb_onepass
      ,LPAD(TRIM(TO_CHAR(multipasses_executions, '999,999,999')), 10) AS nb_multi
      ,LPAD(TRIM(TO_CHAR(
          ROUND((onepass_executions + multipasses_executions) * 100 /
                NULLIF(optimal_executions + onepass_executions + multipasses_executions, 0), 1)
          , '990.0')) || '%', 8)                                 AS pct_overflow
  FROM v$sql_workarea_histogram
 WHERE optimal_executions + onepass_executions + multipasses_executions > 0
 ORDER BY low_optimal_size
;

PROMPT
PROMPT  Workareas actives en ce moment :
PROMPT

-- -----------------------------------------------
-- 3. Workareas en cours d'execution
-- -----------------------------------------------

COL sid       FORMAT 9999    HEAD "SID"
COL operation FORMAT A20     HEAD "Operation"
COL policy    FORMAT A12     HEAD "Policy"
COL expected  FORMAT A12     HEAD "Attendu"
COL active    FORMAT A12     HEAD "Actif"
COL passes    FORMAT 999     HEAD "Passes"

SELECT sid
      ,operation_type                                            AS operation
      ,policy
      ,LPAD(TRIM(TO_CHAR(expected_size/1024/1024, '999,999')) || ' MB', 10) AS expected
      ,LPAD(TRIM(TO_CHAR(actual_mem_used/1024/1024, '999,999')) || ' MB', 10) AS active
      ,number_passes                                             AS passes
  FROM v$sql_workarea_active
 ORDER BY actual_mem_used DESC
 FETCH FIRST 10 ROWS ONLY
;

PROMPT
PROMPT  Actions :
PROMPT  Multipass > 0          --> PGA sous-dimensionnee, augmenter PGA_AGGREGATE_TARGET
PROMPT  % Overflow > 5%        --> Verifier requetes : index manquants ou PGA petite
PROMPT  Passes > 1 (actif)     --> Workarea en cours de spill sur TEMP (lent)
PROMPT  Policy = MANUAL        --> Verifier SORT_AREA_SIZE / HASH_AREA_SIZE
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_9
