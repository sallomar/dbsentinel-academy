-- ============================================================================
-- SCRIPT     : check_bgprocess.sql
-- MODULE     : M1.5 - Processus Background Oracle
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @check_bgprocess.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== PROCESSUS BACKGROUND - DIAGNOSTIC RAPIDE ====================
PROMPT

-- -----------------------------------------------
-- 1. Tous les processus background actifs
-- -----------------------------------------------

COL nom         FORMAT A10  HEAD "Processus"
COL description FORMAT A40  HEAD "Description"
COL pid         FORMAT A8   HEAD "PID OS"
COL pga_mb      FORMAT A12  HEAD "PGA (MB)"

SELECT b.name                                                   AS nom
      ,b.description                                            AS description
      ,p.spid                                                   AS pid
      ,LPAD(CASE WHEN p.pga_alloc_mem >= 1048576
            THEN TRIM(TO_CHAR(p.pga_alloc_mem/1048576, '999.9')) || ' MB'
            ELSE TRIM(TO_CHAR(p.pga_alloc_mem/1024, '9999')) || ' KB'
       END, 10)                                                 AS pga_mb
  FROM v$bgprocess b
  JOIN v$process p ON b.paddr = p.addr
 WHERE b.paddr != '00'
 ORDER BY b.name
;

PROMPT
PROMPT  Processus critiques (si absent = PROBLEME) :
PROMPT

-- -----------------------------------------------
-- 2. Verification des 5 processus critiques
-- -----------------------------------------------

COL processus FORMAT A8   HEAD "Critique"
COL statut    FORMAT A12  HEAD "Statut"
COL role_desc FORMAT A70  HEAD "Role"

WITH critiques AS (
    SELECT 'PMON' AS nom, 'Nettoyage sessions mortes. Si absent = instance crashee'          AS role_desc, 1 AS ordre FROM dual UNION ALL
    SELECT 'SMON',        'Recovery crash + nettoyage segments. Si absent = instance instable',             2 FROM dual UNION ALL
    SELECT 'LGWR',        'Ecriture redo logs au COMMIT. Si absent = perte transactions',                  3 FROM dual UNION ALL
    SELECT 'DBW0',        'Ecriture dirty buffers vers datafiles. Si bloque = free buffer waits',          4 FROM dual UNION ALL
    SELECT 'CKPT',        'Synchronisation checkpoint SGA/disque. Orchestre DBWn',                         5 FROM dual
)
SELECT c.nom                                                    AS processus
      ,CASE WHEN b.name IS NOT NULL
            THEN 'ACTIF'
            ELSE '** ABSENT **'
       END                                                      AS statut
      ,c.role_desc
  FROM critiques c
  LEFT JOIN v$bgprocess b ON c.nom = b.name AND b.paddr != '00'
 ORDER BY c.ordre
;

PROMPT
PROMPT  Resume processus :
PROMPT

-- -----------------------------------------------
-- 3. Resume : total processus + mode archivage
-- -----------------------------------------------

COL information FORMAT A35  HEAD "Information"
COL valeur      FORMAT A20  HEAD "Valeur"

SELECT 'Processus background actifs'             AS information
      ,TRIM(TO_CHAR(COUNT(*), '999'))            AS valeur
  FROM v$bgprocess
 WHERE paddr != '00'
UNION ALL
SELECT 'Dont DBWn (Database Writers)'
      ,TRIM(TO_CHAR(COUNT(*), '999'))
  FROM v$bgprocess
 WHERE name LIKE 'DBW%' AND paddr != '00'
UNION ALL
SELECT 'Dont ARCn (Archivers)'
      ,TRIM(TO_CHAR(COUNT(*), '999'))
  FROM v$bgprocess
 WHERE name LIKE 'ARC%' AND paddr != '00'
UNION ALL
SELECT 'Mode archivage'
      ,log_mode
  FROM v$database
;

PROMPT
PROMPT  PMON, SMON, LGWR = Si l'un meurt, l'instance CRASH
PROMPT  DBWn bloque = free buffer waits (sessions lentes)
PROMPT  ARCn bloque = ORA-00257 (base FREEZE en ARCHIVELOG)
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_5
