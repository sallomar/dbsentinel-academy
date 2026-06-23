-- ============================================================================
-- SCRIPT     : v_undo_transactions.sql
-- MODULE     : M1.10 - UNDO Tablespace et Transactions
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_undo_transactions.sql
-- ============================================================================

SET LINESIZE 220
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== UNDO - TRANSACTIONS ACTIVES ====================
PROMPT
PROMPT  Note : sections vides = aucune transaction n'est ouverte actuellement
PROMPT

-- -----------------------------------------------
-- 1. Transactions actives consommant de l'UNDO (top 15)
-- -----------------------------------------------

COL sid_serial FORMAT A14   HEAD "SID,Serial"
COL utilisateur FORMAT A15  HEAD "Utilisateur"
COL programme  FORMAT A22   HEAD "Programme"
COL duree      FORMAT A12   HEAD "Duree"
COL undo_mb    FORMAT A12   HEAD "UNDO genere"
COL nb_lignes  FORMAT A12   HEAD "Lignes UNDO"
COL sql_id     FORMAT A14   HEAD "SQL_ID"

SELECT TRIM(TO_CHAR(s.sid)) || ',' || TRIM(TO_CHAR(s.serial#))    AS sid_serial
      ,NVL(s.username, 'BACKGROUND')                              AS utilisateur
      ,SUBSTR(NVL(s.program, '-'), 1, 22)                         AS programme
      ,LPAD(
          TRIM(TO_CHAR(FLOOR((SYSDATE - t.start_date) * 24), '90')) || 'h'
          || TRIM(TO_CHAR(MOD(FLOOR((SYSDATE - t.start_date) * 1440), 60), 'FM00')) || 'm'
       , 11)                                                      AS duree
      ,LPAD(TRIM(TO_CHAR(t.used_ublk * 8 / 1024, '999,999.0')) || ' MB', 12) AS undo_mb
      ,LPAD(TRIM(TO_CHAR(t.used_urec, '999,999,999')), 12)        AS nb_lignes
      ,NVL(s.sql_id, '-')                                         AS sql_id
  FROM v$transaction t
  JOIN v$session s ON t.addr = s.taddr
 ORDER BY t.used_ublk DESC
 FETCH FIRST 15 ROWS ONLY
;

PROMPT
PROMPT  Repartition par segment de rollback (UNDO) :
PROMPT

-- -----------------------------------------------
-- 2. Activite par segment UNDO (rollback segment)
-- -----------------------------------------------

COL segment_undo FORMAT A24  HEAD "Segment UNDO"
COL nb_txn       FORMAT 9999 HEAD "Txn"
COL undo_total   FORMAT A14  HEAD "UNDO actif"
COL lignes_total FORMAT A16  HEAD "Lignes UNDO"

SELECT r.name                                                     AS segment_undo
      ,COUNT(*)                                                   AS nb_txn
      ,LPAD(TRIM(TO_CHAR(SUM(t.used_ublk) * 8 / 1024, '999,999.0')) || ' MB', 12) AS undo_total
      ,LPAD(TRIM(TO_CHAR(SUM(t.used_urec), '999,999,999')), 14)   AS lignes_total
  FROM v$transaction t
  JOIN v$rollname r ON t.xidusn = r.usn
 GROUP BY r.name
 ORDER BY SUM(t.used_ublk) DESC
;

PROMPT
PROMPT  Transactions longues a surveiller (> 30 min) :
PROMPT

-- -----------------------------------------------
-- 3. Transactions longues = risque rollback long + ORA-30036
-- -----------------------------------------------

COL sid_serial FORMAT A14   HEAD "SID,Serial"
COL utilisateur FORMAT A15  HEAD "Utilisateur"
COL debut      FORMAT A20   HEAD "Debut transaction"
COL duree_min  FORMAT A12   HEAD "Duree"
COL undo_mb    FORMAT A12   HEAD "UNDO genere"
COL alerte     FORMAT A28   HEAD "Alerte"

SELECT TRIM(TO_CHAR(s.sid)) || ',' || TRIM(TO_CHAR(s.serial#))    AS sid_serial
      ,NVL(s.username, 'BACKGROUND')                              AS utilisateur
      ,t.start_time                                               AS debut
      ,LPAD(TRIM(TO_CHAR(ROUND((SYSDATE - t.start_date) * 1440), '999,999')) || ' min', 11) AS duree_min
      ,LPAD(TRIM(TO_CHAR(t.used_ublk * 8 / 1024, '999,999.0')) || ' MB', 12) AS undo_mb
      ,CASE
            WHEN (SYSDATE - t.start_date) * 1440 > 180
            THEN '!! ROLLBACK tres long si KILL'
            WHEN (SYSDATE - t.start_date) * 1440 > 30
            THEN 'Surveiller (txn longue)'
            ELSE 'OK'
       END                                                        AS alerte
  FROM v$transaction t
  JOIN v$session s ON t.addr = s.taddr
 WHERE (SYSDATE - t.start_date) * 1440 > 30
 ORDER BY t.start_date
;

PROMPT
PROMPT  Lecture :
PROMPT  UNDO genere = blocs UNDO x 8K (taille du before-image accumule)
PROMPT  Lignes UNDO = nombre d'enregistrements annulables (USED_UREC)
PROMPT
PROMPT  Txn longue + gros UNDO --> un KILL SESSION declenche un rollback long
PROMPT  Txn jamais committee   --> bloque le recyclage de l'UNDO (risque ORA-30036)
PROMPT  ROLLBACK 1M lignes     --> Oracle relit tout l'UNDO (peut durer des heures)
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_10
