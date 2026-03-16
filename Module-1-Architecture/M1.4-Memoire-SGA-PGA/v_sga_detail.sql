-- ============================================================================
-- SCRIPT     : v_sga_detail.sql
-- MODULE     : M1.4 - Memoire Oracle : SGA et PGA
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_sga_detail.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== SGA - ANALYSE DETAILLEE ====================
PROMPT

-- -----------------------------------------------
-- 1. Vue globale SGA (V$SGAINFO)
-- -----------------------------------------------

COL nom     FORMAT A35 HEAD "Composant"
COL taille  FORMAT A12 HEAD "Taille"

SELECT name AS nom,
       CASE
         WHEN bytes >= 1073741824
           THEN LPAD(TRIM(TO_CHAR(ROUND(bytes/1073741824, 1), '999,999.0')) || ' GB', 12)
         ELSE LPAD(TRIM(TO_CHAR(ROUND(bytes/1048576), '999,999')) || ' MB', 12)
       END AS taille
FROM   v$sgainfo
WHERE  bytes > 0
ORDER BY bytes DESC;

-- -----------------------------------------------
-- 2. Composants dynamiques (auto-tuning ASMM)
-- -----------------------------------------------

PROMPT
PROMPT  Composants dynamiques (ASMM - Auto Shared Memory Management) :
PROMPT

COL composant   FORMAT A30 HEAD "Composant"
COL actuel_mb   FORMAT A12 HEAD "Actuel"
COL min_mb      FORMAT A12 HEAD "Min"
COL max_mb      FORMAT A12 HEAD "Max atteint"
COL nb_resize   FORMAT 9999 HEAD "Resizes"

SELECT component AS composant,
       CASE WHEN current_size/1048576 >= 1024
            THEN LPAD(TRIM(TO_CHAR(ROUND(current_size/1073741824, 1), '999.0')) || ' GB', 12)
            ELSE LPAD(TRIM(TO_CHAR(ROUND(current_size/1048576), '999,999')) || ' MB', 12)
       END AS actuel_mb,
       CASE WHEN min_size/1048576 >= 1024
            THEN LPAD(TRIM(TO_CHAR(ROUND(min_size/1073741824, 1), '999.0')) || ' GB', 12)
            ELSE LPAD(TRIM(TO_CHAR(ROUND(min_size/1048576), '999,999')) || ' MB', 12)
       END AS min_mb,
       CASE WHEN max_size/1048576 >= 1024
            THEN LPAD(TRIM(TO_CHAR(ROUND(max_size/1073741824, 1), '999.0')) || ' GB', 12)
            ELSE LPAD(TRIM(TO_CHAR(ROUND(max_size/1048576), '999,999')) || ' MB', 12)
       END AS max_mb,
       oper_count AS nb_resize
FROM   v$sga_dynamic_components
WHERE  current_size > 0
ORDER BY current_size DESC;

-- -----------------------------------------------
-- 3. Buffer Cache Hit Ratio (efficacite)
-- -----------------------------------------------

PROMPT
PROMPT  Efficacite Buffer Cache :
PROMPT

COL metrique    FORMAT A35  HEAD "Metrique"
COL valeur      FORMAT A15  HEAD "Valeur"
COL diagnostic  FORMAT A30  HEAD "Diagnostic"

SELECT 'Buffer Cache Hit Ratio' AS metrique,
       LPAD(TO_CHAR(
         ROUND(1 - (phy.value / NULLIF(con.value + db.value, 0)), 4) * 100,
         '999.99') || '%', 15) AS valeur,
       CASE
         WHEN ROUND(1 - (phy.value / NULLIF(con.value + db.value, 0)), 4) * 100 >= 99
           THEN 'EXCELLENT (>= 99%)'
         WHEN ROUND(1 - (phy.value / NULLIF(con.value + db.value, 0)), 4) * 100 >= 95
           THEN 'BON (>= 95%)'
         WHEN ROUND(1 - (phy.value / NULLIF(con.value + db.value, 0)), 4) * 100 >= 90
           THEN 'ACCEPTABLE (>= 90%)'
         ELSE '!! FAIBLE - Augmenter Buffer Cache'
       END AS diagnostic
FROM   (SELECT value FROM v$sysstat WHERE name = 'physical reads') phy,
       (SELECT value FROM v$sysstat WHERE name = 'consistent gets') con,
       (SELECT value FROM v$sysstat WHERE name = 'db block gets') db;

-- -----------------------------------------------
-- 4. SGA Target Advice (recommandation Oracle)
-- -----------------------------------------------

PROMPT
PROMPT  Conseil Oracle (V$SGA_TARGET_ADVICE) :
PROMPT  (DB Time Factor < 1 = amelioration si SGA plus grande)
PROMPT

COL sga_taille  FORMAT A12 HEAD "SGA"
COL facteur     FORMAT A10 HEAD "Factor"
COL db_time_pct FORMAT A12 HEAD "DB Time %"
COL conseil     FORMAT A25 HEAD "Conseil"

SELECT CASE
         WHEN sga_size >= 1024
           THEN LPAD(TRIM(TO_CHAR(ROUND(sga_size/1024, 1), '999.0')) || ' GB', 12)
         ELSE LPAD(TRIM(TO_CHAR(sga_size, '999,999')) || ' MB', 12)
       END AS sga_taille,
       LPAD(TO_CHAR(sga_size_factor, '0.99'), 10) AS facteur,
       LPAD(TO_CHAR(ROUND(estd_db_time_factor * 100), '999,999'), 12) AS db_time_pct,
       CASE
         WHEN sga_size_factor = 1 THEN '--> CONFIG ACTUELLE'
         WHEN estd_db_time_factor < 0.95 THEN 'Gain possible'
         WHEN estd_db_time_factor > 1.1  THEN 'Degradation'
         ELSE ' '
       END AS conseil
FROM   v$sga_target_advice
WHERE  sga_size_factor BETWEEN 0.5 AND 2
ORDER BY sga_size;

PROMPT
PROMPT  Actions :
PROMPT  Hit Ratio < 95%         --> Augmenter SGA_TARGET (Buffer Cache)
PROMPT  Shared Pool saturation  --> Verifier curseurs non partages
PROMPT  Factor < 1 (advice)     --> SGA actuelle peut etre trop petite
PROMPT
PROMPT =================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_4
