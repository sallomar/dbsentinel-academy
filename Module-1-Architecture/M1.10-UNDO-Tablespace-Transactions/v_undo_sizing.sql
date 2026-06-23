-- ============================================================================
-- SCRIPT     : v_undo_sizing.sql
-- MODULE     : M1.10 - UNDO Tablespace et Transactions
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_undo_sizing.sql
-- ============================================================================

SET LINESIZE 220
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== UNDO - SIZING ET RECOMMANDATIONS ====================
PROMPT

-- -----------------------------------------------
-- 1. Parametres de reference (retention, block size)
-- -----------------------------------------------

COL parametre  FORMAT A42  HEAD "Parametre"
COL valeur_par FORMAT A25  HEAD "Valeur"
COL impact     FORMAT A48  HEAD "Impact sur le sizing UNDO"

SELECT 'UNDO_RETENTION (cible)'                                   AS parametre
      ,TRIM(TO_CHAR(TO_NUMBER(value), '999,999')) || ' s'         AS valeur_par
      ,'Duree min de conservation visee de l''UNDO'               AS impact
  FROM v$parameter
 WHERE name = 'undo_retention'
UNION ALL
SELECT 'Retention auto-tunee (max observe)'
      ,TRIM(TO_CHAR(MAX(tuned_undoretention), '999,999')) || ' s'
      ,'Retention reellement appliquee par Oracle'
  FROM v$undostat
UNION ALL
SELECT 'DB_BLOCK_SIZE'
      ,TRIM(TO_CHAR(TO_NUMBER(value), '999,999')) || ' o'
      ,'Taille d''un bloc UNDO (base du calcul)'
  FROM v$parameter
 WHERE name = 'db_block_size'
UNION ALL
SELECT 'Requete la plus longue (MAXQUERYLEN)'
      ,TRIM(TO_CHAR(MAX(maxquerylen), '999,999')) || ' s'
      ,'Retention minimale pour eviter ORA-01555'
  FROM v$undostat
;

PROMPT
PROMPT  Consommation UNDO observee (V$UNDOSTAT) :
PROMPT

-- -----------------------------------------------
-- 2. Pic de consommation UNDO par intervalle (10 min)
-- -----------------------------------------------

COL indicateur FORMAT A45  HEAD "Indicateur de charge"
COL valeur_ind FORMAT A22  HEAD "Valeur"

-- Agregation isolee dans un CTE puis arithmetique simple
-- (evite ORA-00937 : agregat + sous-requete scalaire dans la meme expression)
WITH blk AS (
    SELECT TO_NUMBER(value) AS bsize
      FROM v$parameter
     WHERE name = 'db_block_size'
),
us AS (
    SELECT MAX(undoblks) AS peak_blks
          ,MAX(txncount) AS max_txn
      FROM v$undostat
)
SELECT 'Pic de blocs UNDO / intervalle 10 min'                   AS indicateur
      ,LPAD(TRIM(TO_CHAR(us.peak_blks, '999,999,999')), 18)       AS valeur_ind
  FROM us
UNION ALL
SELECT 'Pic UNDO genere / intervalle 10 min'
      ,LPAD(TRIM(TO_CHAR(us.peak_blks * blk.bsize / 1048576, '999,999.9')) || ' MB', 18)
  FROM us, blk
UNION ALL
SELECT 'Debit UNDO de pointe (par minute)'
      ,LPAD(TRIM(TO_CHAR(us.peak_blks * blk.bsize / 1048576 / 10, '999,999.9')) || ' MB', 18)
  FROM us, blk
UNION ALL
SELECT 'Transactions max / intervalle'
      ,LPAD(TRIM(TO_CHAR(us.max_txn, '999,999,999')), 18)
  FROM us
;

PROMPT
PROMPT  Comparaison UNDO actuel vs recommande :
PROMPT

-- -----------------------------------------------
-- 3. Calcul du sizing recommande
--    UNDO requis = debit_pointe(blocs/s) x retention x block_size
-- -----------------------------------------------

COL element       FORMAT A42  HEAD "Element"
COL valeur_calc   FORMAT A18  HEAD "Valeur"
COL recommandation FORMAT A50 HEAD "Recommandation"

WITH cfg AS (
    SELECT MAX(CASE WHEN name = 'db_block_size'  THEN TO_NUMBER(value) END) AS blk
          ,MAX(CASE WHEN name = 'undo_retention' THEN TO_NUMBER(value) END) AS ret
      FROM v$parameter
     WHERE name IN ('db_block_size', 'undo_retention')
),
stat AS (
    SELECT MAX(undoblks)      AS peak_blks
          ,MAX(maxquerylen)   AS max_query
      FROM v$undostat
),
alloc AS (
    SELECT SUM(d.bytes)       AS current_bytes
          ,SUM(CASE WHEN d.autoextensible = 'YES' THEN d.maxbytes ELSE d.bytes END) AS max_bytes
      FROM dba_data_files d
      JOIN dba_tablespaces ts ON d.tablespace_name = ts.tablespace_name
     WHERE ts.contents = 'UNDO'
)
SELECT 'UNDO actuellement alloue'                                 AS element
      ,LPAD(TRIM(TO_CHAR(a.current_bytes/1073741824, '999,990.9')) || ' GB', 14) AS valeur_calc
      ,'-'                                                        AS recommandation
  FROM alloc a
UNION ALL
SELECT 'UNDO max (avec AUTOEXTEND)'
      ,LPAD(TRIM(TO_CHAR(a.max_bytes/1073741824, '999,990.9')) || ' GB', 14)
      ,'-'
  FROM alloc a
UNION ALL
SELECT 'UNDO requis (retention configuree)'
      ,LPAD(TRIM(TO_CHAR(
          (s.peak_blks / 600) * c.ret * c.blk / 1073741824, '999,990.9')) || ' GB', 14)
      ,CASE WHEN a.max_bytes >= (s.peak_blks / 600) * c.ret * c.blk
            THEN 'OK : capacite max suffisante'
            ELSE '!! Etendre UNDO ou augmenter MAXSIZE'
       END
  FROM cfg c, stat s, alloc a
UNION ALL
SELECT 'UNDO requis + marge securite (x1.5)'
      ,LPAD(TRIM(TO_CHAR(
          (s.peak_blks / 600) * c.ret * c.blk * 1.5 / 1073741824, '999,990.9')) || ' GB', 14)
      ,CASE WHEN a.max_bytes >= (s.peak_blks / 600) * c.ret * c.blk * 1.5
            THEN 'OK : optimal avec marge'
            ELSE 'A AMELIORER : envisager extension'
       END
  FROM cfg c, stat s, alloc a
UNION ALL
SELECT 'Retention min conseillee (MAXQUERYLEN +20%)'
      ,LPAD(TRIM(TO_CHAR(ROUND(s.max_query * 1.2), '999,999')) || ' s', 14)
      ,CASE WHEN c.ret >= s.max_query * 1.2
            THEN 'OK : retention couvre les requetes longues'
            ELSE '!! Risque ORA-01555 sur requetes longues'
       END
  FROM cfg c, stat s, alloc a
;

PROMPT
PROMPT  Regle d'or sizing UNDO :
PROMPT  UNDO requis = (pic blocs/s) x UNDO_RETENTION x DB_BLOCK_SIZE
PROMPT  Marge de securite recommandee : x1.5
PROMPT  UNDO_RETENTION > duree de la requete la plus longue (MAXQUERYLEN) + 20%
PROMPT  AUTOEXTEND ON obligatoire en production (avec MAXSIZE plafonne)
PROMPT  Batch nocturne long --> ajuster UNDO_RETENTION AVANT le batch
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_10
