-- ============================================================================
-- SCRIPT     : v_log_switch_analysis.sql
-- MODULE     : M1.7 - Online Redo Logs et Archivelog
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_log_switch_analysis.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== LOG SWITCHES - ANALYSE FREQUENCE ====================
PROMPT

-- -----------------------------------------------
-- 1. Log switches par heure (dernieres 24h)
-- -----------------------------------------------

COL jour      FORMAT A12  HEAD "Date"
COL h00       FORMAT 999  HEAD "00h"
COL h01       FORMAT 999  HEAD "01h"
COL h02       FORMAT 999  HEAD "02h"
COL h03       FORMAT 999  HEAD "03h"
COL h04       FORMAT 999  HEAD "04h"
COL h05       FORMAT 999  HEAD "05h"
COL h06       FORMAT 999  HEAD "06h"
COL h07       FORMAT 999  HEAD "07h"
COL h08       FORMAT 999  HEAD "08h"
COL h09       FORMAT 999  HEAD "09h"
COL h10       FORMAT 999  HEAD "10h"
COL h11       FORMAT 999  HEAD "11h"
COL h12       FORMAT 999  HEAD "12h"
COL h13       FORMAT 999  HEAD "13h"
COL h14       FORMAT 999  HEAD "14h"
COL h15       FORMAT 999  HEAD "15h"
COL h16       FORMAT 999  HEAD "16h"
COL h17       FORMAT 999  HEAD "17h"
COL h18       FORMAT 999  HEAD "18h"
COL h19       FORMAT 999  HEAD "19h"
COL h20       FORMAT 999  HEAD "20h"
COL h21       FORMAT 999  HEAD "21h"
COL h22       FORMAT 999  HEAD "22h"
COL h23       FORMAT 999  HEAD "23h"
COL total     FORMAT 999  HEAD "Tot"

SELECT TO_CHAR(first_time, 'DD/MM/YYYY')                         AS jour
      ,SUM(CASE WHEN TO_CHAR(first_time,'HH24') = '00' THEN 1 ELSE 0 END) AS h00
      ,SUM(CASE WHEN TO_CHAR(first_time,'HH24') = '01' THEN 1 ELSE 0 END) AS h01
      ,SUM(CASE WHEN TO_CHAR(first_time,'HH24') = '02' THEN 1 ELSE 0 END) AS h02
      ,SUM(CASE WHEN TO_CHAR(first_time,'HH24') = '03' THEN 1 ELSE 0 END) AS h03
      ,SUM(CASE WHEN TO_CHAR(first_time,'HH24') = '04' THEN 1 ELSE 0 END) AS h04
      ,SUM(CASE WHEN TO_CHAR(first_time,'HH24') = '05' THEN 1 ELSE 0 END) AS h05
      ,SUM(CASE WHEN TO_CHAR(first_time,'HH24') = '06' THEN 1 ELSE 0 END) AS h06
      ,SUM(CASE WHEN TO_CHAR(first_time,'HH24') = '07' THEN 1 ELSE 0 END) AS h07
      ,SUM(CASE WHEN TO_CHAR(first_time,'HH24') = '08' THEN 1 ELSE 0 END) AS h08
      ,SUM(CASE WHEN TO_CHAR(first_time,'HH24') = '09' THEN 1 ELSE 0 END) AS h09
      ,SUM(CASE WHEN TO_CHAR(first_time,'HH24') = '10' THEN 1 ELSE 0 END) AS h10
      ,SUM(CASE WHEN TO_CHAR(first_time,'HH24') = '11' THEN 1 ELSE 0 END) AS h11
      ,SUM(CASE WHEN TO_CHAR(first_time,'HH24') = '12' THEN 1 ELSE 0 END) AS h12
      ,SUM(CASE WHEN TO_CHAR(first_time,'HH24') = '13' THEN 1 ELSE 0 END) AS h13
      ,SUM(CASE WHEN TO_CHAR(first_time,'HH24') = '14' THEN 1 ELSE 0 END) AS h14
      ,SUM(CASE WHEN TO_CHAR(first_time,'HH24') = '15' THEN 1 ELSE 0 END) AS h15
      ,SUM(CASE WHEN TO_CHAR(first_time,'HH24') = '16' THEN 1 ELSE 0 END) AS h16
      ,SUM(CASE WHEN TO_CHAR(first_time,'HH24') = '17' THEN 1 ELSE 0 END) AS h17
      ,SUM(CASE WHEN TO_CHAR(first_time,'HH24') = '18' THEN 1 ELSE 0 END) AS h18
      ,SUM(CASE WHEN TO_CHAR(first_time,'HH24') = '19' THEN 1 ELSE 0 END) AS h19
      ,SUM(CASE WHEN TO_CHAR(first_time,'HH24') = '20' THEN 1 ELSE 0 END) AS h20
      ,SUM(CASE WHEN TO_CHAR(first_time,'HH24') = '21' THEN 1 ELSE 0 END) AS h21
      ,SUM(CASE WHEN TO_CHAR(first_time,'HH24') = '22' THEN 1 ELSE 0 END) AS h22
      ,SUM(CASE WHEN TO_CHAR(first_time,'HH24') = '23' THEN 1 ELSE 0 END) AS h23
      ,COUNT(*)                                                  AS total
  FROM v$log_history
 WHERE first_time >= SYSDATE - 7
 GROUP BY TO_CHAR(first_time, 'DD/MM/YYYY')
 ORDER BY TO_DATE(TO_CHAR(first_time, 'DD/MM/YYYY'), 'DD/MM/YYYY')
;

PROMPT
PROMPT  Recommandation dimensionnement :
PROMPT

-- -----------------------------------------------
-- 2. Synthese et recommandation taille
-- -----------------------------------------------

COL metrique    FORMAT A45  HEAD "Metrique"
COL valeur_calc FORMAT A45  HEAD "Valeur"

SELECT 'Taille actuelle des redo logs'                           AS metrique
      ,TRIM(TO_CHAR(MIN(bytes)/1048576, '999')) || ' MB par groupe'  AS valeur_calc
  FROM v$log
UNION ALL
SELECT 'Switches max par heure (7 derniers jours)'
      ,TRIM(TO_CHAR(MAX(cnt), '999')) || ' switches/h'
  FROM (
    SELECT TO_CHAR(first_time, 'DD/MM/YYYY HH24') AS heure
          ,COUNT(*) AS cnt
      FROM v$log_history
     WHERE first_time >= SYSDATE - 7
     GROUP BY TO_CHAR(first_time, 'DD/MM/YYYY HH24')
  )
UNION ALL
SELECT 'Switches moyen par heure'
      ,TRIM(TO_CHAR(AVG(cnt), '990.0')) || ' switches/h'
  FROM (
    SELECT TO_CHAR(first_time, 'DD/MM/YYYY HH24') AS heure
          ,COUNT(*) AS cnt
      FROM v$log_history
     WHERE first_time >= SYSDATE - 7
     GROUP BY TO_CHAR(first_time, 'DD/MM/YYYY HH24')
  )
UNION ALL
SELECT 'Diagnostic'
      ,CASE WHEN MAX(cnt) > 6
            THEN '!! Redo logs trop petits (> 6 switches/h)'
            WHEN MAX(cnt) > 4
            THEN 'Surveiller (4-6 switches/h)'
            ELSE 'OK (objectif : 2-4 switches/h max)'
       END
  FROM (
    SELECT COUNT(*) AS cnt
      FROM v$log_history
     WHERE first_time >= SYSDATE - 7
     GROUP BY TO_CHAR(first_time, 'DD/MM/YYYY HH24')
  )
;

PROMPT
PROMPT  Objectif : 2 a 4 log switches par heure maximum
PROMPT  > 6 switches/h = redo logs sous-dimensionnes, augmenter taille
PROMPT  Formule : Taille = (Volume_redo/h / nb_groupes) x 1.2
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_7
