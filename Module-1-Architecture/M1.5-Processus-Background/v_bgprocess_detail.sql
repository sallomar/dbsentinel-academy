-- ============================================================================
-- SCRIPT     : v_bgprocess_detail.sql
-- MODULE     : M1.5 - Processus Background Oracle
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_bgprocess_detail.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== PROCESSUS BACKGROUND - ANALYSE DETAILLEE ====================
PROMPT

-- -----------------------------------------------
-- 1. Memoire PGA par processus background
-- -----------------------------------------------

COL nom         FORMAT A8   HEAD "Process"
COL description FORMAT A40  HEAD "Description"
COL pid         FORMAT A8   HEAD "PID OS"
COL pga_used    FORMAT A12  HEAD "PGA Used"
COL pga_alloc   FORMAT A12  HEAD "PGA Alloc"
COL pga_max     FORMAT A12  HEAD "PGA Max"

SELECT b.name                                                   AS nom
      ,b.description                                            AS description
      ,p.spid                                                   AS pid
      ,LPAD(CASE WHEN p.pga_used_mem >= 1048576
            THEN TRIM(TO_CHAR(p.pga_used_mem/1048576, '999.9')) || ' MB'
            ELSE TRIM(TO_CHAR(p.pga_used_mem/1024, '9999')) || ' KB'
       END, 10)                                                 AS pga_used
      ,LPAD(CASE WHEN p.pga_alloc_mem >= 1048576
            THEN TRIM(TO_CHAR(p.pga_alloc_mem/1048576, '999.9')) || ' MB'
            ELSE TRIM(TO_CHAR(p.pga_alloc_mem/1024, '9999')) || ' KB'
       END, 10)                                                 AS pga_alloc
      ,LPAD(CASE WHEN p.pga_max_mem >= 1048576
            THEN TRIM(TO_CHAR(p.pga_max_mem/1048576, '999.9')) || ' MB'
            ELSE TRIM(TO_CHAR(p.pga_max_mem/1024, '9999')) || ' KB'
       END, 10)                                                 AS pga_max
  FROM v$bgprocess b
  JOIN v$process p ON b.paddr = p.addr
 WHERE b.paddr != '00'
 ORDER BY p.pga_alloc_mem DESC
;

PROMPT
PROMPT  Top 5 processus background par PGA :
PROMPT

-- -----------------------------------------------
-- 2. Top 5 processus les plus gourmands
-- -----------------------------------------------

COL rang      FORMAT 99    HEAD "#"
COL nom       FORMAT A8    HEAD "Process"
COL pga_mb    FORMAT A10   HEAD "PGA (MB)"
COL pct_total FORMAT A8    HEAD "% Total"

SELECT rn                                                       AS rang
      ,nom
      ,pga_mb
      ,pct_total
  FROM (
    SELECT ROW_NUMBER() OVER (ORDER BY p.pga_alloc_mem DESC)    AS rn
          ,b.name                                               AS nom
          ,LPAD(TRIM(TO_CHAR(p.pga_alloc_mem/1048576, '999.9')), 8) AS pga_mb
          ,LPAD(TRIM(TO_CHAR(
              p.pga_alloc_mem * 100 / NULLIF(SUM(p.pga_alloc_mem) OVER (), 0)
              , '990.0')) || '%', 7)                             AS pct_total
      FROM v$bgprocess b
      JOIN v$process p ON b.paddr = p.addr
     WHERE b.paddr != '00'
  )
 WHERE rn <= 5
;

PROMPT
PROMPT  Fichiers trace des processus critiques :
PROMPT

-- -----------------------------------------------
-- 3. Localisation fichiers trace (debug)
-- -----------------------------------------------

COL nom       FORMAT A8   HEAD "Process"
COL tracefile FORMAT A90  HEAD "Fichier Trace"

SELECT b.name                                                   AS nom
      ,p.tracefile
  FROM v$bgprocess b
  JOIN v$process p ON b.paddr = p.addr
 WHERE b.paddr != '00'
   AND b.name IN ('PMON', 'SMON', 'LGWR', 'DBW0', 'CKPT', 'ARC0')
 ORDER BY CASE b.name
    WHEN 'PMON' THEN 1 WHEN 'SMON' THEN 2 WHEN 'LGWR' THEN 3
    WHEN 'DBW0' THEN 4 WHEN 'CKPT' THEN 5 WHEN 'ARC0' THEN 6 END
;

PROMPT
PROMPT  Actions :
PROMPT  PGA process > 100 MB       --> Verifier activite anormale
PROMPT  Trace file modifie         --> Verifier erreurs ORA dans le fichier
PROMPT  Debug temps reel           --> tail -f tracefile (Linux) ou type tracefile (Windows)
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_5
