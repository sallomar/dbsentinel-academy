-- ============================================================================
-- SCRIPT     : v_ora01555_diag.sql
-- MODULE     : M1.10 - UNDO Tablespace et Transactions
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_ora01555_diag.sql
-- ============================================================================

SET LINESIZE 220
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ============== DIAGNOSTIC ORA-01555 / ORA-30036 (V$UNDOSTAT) ==============
PROMPT
PROMPT  V$UNDOSTAT conserve environ 4 jours d'historique (intervalles de 10 min)
PROMPT

-- -----------------------------------------------
-- 1. Synthese des erreurs UNDO sur la periode
-- -----------------------------------------------

COL indicateur FORMAT A48  HEAD "Indicateur sur la periode"
COL valeur_ind FORMAT A22  HEAD "Valeur"
COL verdict    FORMAT A40  HEAD "Verdict"

SELECT 'Total ORA-01555 (snapshot too old)'                      AS indicateur
      ,LPAD(TRIM(TO_CHAR(SUM(ssolderrcnt), '999,999')), 14)       AS valeur_ind
      ,CASE WHEN SUM(ssolderrcnt) > 0
            THEN '!! Retention trop courte / UNDO recycle'
            ELSE 'OK : aucun snapshot too old'
       END                                                        AS verdict
  FROM v$undostat
UNION ALL
SELECT 'Total ORA-30036 (unable to extend)'
      ,LPAD(TRIM(TO_CHAR(SUM(nospaceerrcnt), '999,999')), 14)
      ,CASE WHEN SUM(nospaceerrcnt) > 0
            THEN '!! UNDO plein (etendre / revoir GUARANTEE)'
            ELSE 'OK : aucune erreur d''espace'
       END
  FROM v$undostat
UNION ALL
SELECT 'Requete la plus longue observee'
      ,LPAD(TRIM(TO_CHAR(MAX(maxquerylen), '999,999')) || ' s', 14)
      ,'A comparer a UNDO_RETENTION'
  FROM v$undostat
UNION ALL
SELECT 'UNDO_RETENTION configure'
      ,LPAD(TRIM(TO_CHAR(TO_NUMBER(value), '999,999')) || ' s', 14)
      ,CASE WHEN TO_NUMBER(value) <
                 (SELECT MAX(maxquerylen) FROM v$undostat)
            THEN '!! Inferieur a la requete la plus longue'
            ELSE 'OK : couvre les requetes observees'
       END
  FROM v$parameter
 WHERE name = 'undo_retention'
;

PROMPT
PROMPT  Intervalles AVEC erreurs UNDO (a investiguer en priorite) :
PROMPT

-- -----------------------------------------------
-- 2. Detail des intervalles ou des erreurs ont eu lieu
-- -----------------------------------------------

COL debut      FORMAT A20  HEAD "Debut intervalle"
COL fin        FORMAT A20  HEAD "Fin intervalle"
COL ora01555   FORMAT A10  HEAD "ORA-01555"
COL ora30036   FORMAT A10  HEAD "ORA-30036"
COL maxquery   FORMAT A12  HEAD "Req. longue"
COL tuned_ret  FORMAT A14  HEAD "Ret. tunee"

SELECT TO_CHAR(begin_time, 'DD/MM HH24:MI')                       AS debut
      ,TO_CHAR(end_time,   'DD/MM HH24:MI')                       AS fin
      ,LPAD(TRIM(TO_CHAR(ssolderrcnt, '999,999')), 9)             AS ora01555
      ,LPAD(TRIM(TO_CHAR(nospaceerrcnt, '999,999')), 9)           AS ora30036
      ,LPAD(TRIM(TO_CHAR(maxquerylen, '999,999')) || ' s', 11)    AS maxquery
      ,LPAD(TRIM(TO_CHAR(tuned_undoretention, '999,999')) || ' s', 13) AS tuned_ret
  FROM v$undostat
 WHERE ssolderrcnt > 0
    OR nospaceerrcnt > 0
 ORDER BY begin_time DESC
 FETCH FIRST 20 ROWS ONLY
;

PROMPT
PROMPT  Top 10 intervalles par duree de requete (risque ORA-01555) :
PROMPT

-- -----------------------------------------------
-- 3. Intervalles ou les requetes les plus longues ont tourne
-- -----------------------------------------------

COL debut      FORMAT A20  HEAD "Debut intervalle"
COL maxquery   FORMAT A14  HEAD "Req. la + longue"
COL undoblks   FORMAT A14  HEAD "Blocs UNDO"
COL tuned_ret  FORMAT A14  HEAD "Ret. tunee"
COL marge      FORMAT A24  HEAD "Marge retention"

SELECT TO_CHAR(begin_time, 'DD/MM HH24:MI')                       AS debut
      ,LPAD(TRIM(TO_CHAR(maxquerylen, '999,999')) || ' s', 12)    AS maxquery
      ,LPAD(TRIM(TO_CHAR(undoblks, '999,999,999')), 12)           AS undoblks
      ,LPAD(TRIM(TO_CHAR(tuned_undoretention, '999,999')) || ' s', 13) AS tuned_ret
      ,CASE
            WHEN maxquerylen > tuned_undoretention
            THEN '!! Requete > retention'
            WHEN maxquerylen > tuned_undoretention * 0.8
            THEN 'Surveiller (marge faible)'
            ELSE 'OK'
       END                                                        AS marge
  FROM v$undostat
 WHERE maxquerylen > 0
 ORDER BY maxquerylen DESC
 FETCH FIRST 10 ROWS ONLY
;

PROMPT
PROMPT  Plan d'action :
PROMPT  ORA-01555 > 0      --> augmenter UNDO_RETENTION (> MAXQUERYLEN + 20%)
PROMPT  ORA-30036 > 0      --> etendre le tablespace UNDO ou revoir GUARANTEE
PROMPT  Requete > retention--> optimiser la requete OU rallonger la retention
PROMPT  Batch nocturne     --> ALTER SYSTEM SET UNDO_RETENTION avant le batch
PROMPT  Flashback critique --> ALTER TABLESPACE undotbs1 RETENTION GUARANTEE
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_10
