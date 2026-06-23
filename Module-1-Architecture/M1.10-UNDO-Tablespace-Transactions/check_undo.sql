-- ============================================================================
-- SCRIPT     : check_undo.sql
-- MODULE     : M1.10 - UNDO Tablespace et Transactions
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @check_undo.sql
-- ============================================================================

SET LINESIZE 250
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== UNDO TABLESPACE - DIAGNOSTIC RAPIDE ====================
PROMPT

-- -----------------------------------------------
-- 1. Detail de chaque datafile UNDO (allocation + capacite max)
-- -----------------------------------------------

COL tablespace FORMAT A20  HEAD "Tablespace"
COL fichier    FORMAT A65  HEAD "Datafile UNDO"
COL alloue     FORMAT A12  HEAD "Alloue"
COL utilise    FORMAT A12  HEAD "Utilise"
COL pct        FORMAT A8   HEAD "% Util"
COL max_gb     FORMAT A12  HEAD "Max (Auto)"
COL pct_max    FORMAT A8   HEAD "% Max"
COL statut     FORMAT A12  HEAD "Statut"

SELECT d.tablespace_name                                          AS tablespace
      ,d.file_name                                                AS fichier
      ,LPAD(TRIM(TO_CHAR(d.bytes/1048576, '999,999')), 10)        AS alloue
      ,LPAD(TRIM(TO_CHAR(NVL(u.used_bytes,0)/1048576, '999,999')), 10) AS utilise
      ,LPAD(TRIM(TO_CHAR(
          ROUND(NVL(u.used_bytes,0) / d.bytes * 100, 1)
          , '990.0')) || '%', 7)                                  AS pct
      ,CASE WHEN d.autoextensible = 'YES'
            THEN LPAD(TRIM(TO_CHAR(d.maxbytes/1073741824, '999.9')) || ' GB', 10)
            ELSE '       NON'
       END                                                        AS max_gb
      ,LPAD(TRIM(TO_CHAR(
          ROUND(NVL(u.used_bytes,0) /
                CASE WHEN d.autoextensible = 'YES' THEN d.maxbytes ELSE d.bytes END * 100, 1)
          , '990.0')) || '%', 7)                                  AS pct_max
      ,CASE
            -- AUTOEXTEND OFF : alerte sur taille actuelle (vrai plafond)
            WHEN d.autoextensible = 'NO'
                 AND NVL(u.used_bytes,0) / d.bytes * 100 > 85
            THEN '!! CRITIQUE'
            WHEN d.autoextensible = 'NO'
                 AND NVL(u.used_bytes,0) / d.bytes * 100 > 70
            THEN 'Surveiller'
            -- AUTOEXTEND ON : alerte sur capacite MAX (le vrai risque ORA-30036)
            WHEN d.autoextensible = 'YES'
                 AND NVL(u.used_bytes,0) / d.maxbytes * 100 > 85
            THEN '!! CRITIQUE'
            WHEN d.autoextensible = 'YES'
                 AND NVL(u.used_bytes,0) / d.maxbytes * 100 > 70
            THEN 'Surveiller'
            ELSE 'OK'
       END                                                        AS statut
  FROM dba_data_files d
  JOIN dba_tablespaces ts ON d.tablespace_name = ts.tablespace_name
  LEFT JOIN (
        SELECT file_id, SUM(bytes) AS used_bytes
          FROM dba_undo_extents
         WHERE status IN ('ACTIVE', 'UNEXPIRED')
         GROUP BY file_id
       ) u ON u.file_id = d.file_id
 WHERE ts.contents = 'UNDO'
 ORDER BY d.tablespace_name, d.file_id
;

PROMPT
PROMPT  Repartition de l'espace UNDO par statut de bloc :
PROMPT

-- -----------------------------------------------
-- 2. Etat des extents UNDO (ACTIVE / UNEXPIRED / EXPIRED)
-- -----------------------------------------------

COL etat        FORMAT A16  HEAD "Etat bloc UNDO"
COL taille_mb   FORMAT A12  HEAD "Taille"
COL pct_etat    FORMAT A8   HEAD "% UNDO"
COL signification FORMAT A50 HEAD "Signification"

SELECT e.status                                                   AS etat
      ,LPAD(TRIM(TO_CHAR(SUM(e.bytes)/1048576, '999,999')) || ' MB', 12) AS taille_mb
      ,LPAD(TRIM(TO_CHAR(
          ROUND(SUM(e.bytes) * 100 /
                NULLIF(SUM(SUM(e.bytes)) OVER (), 0), 1)
          , '990.0')) || '%', 7)                                  AS pct_etat
      ,CASE e.status
            WHEN 'ACTIVE'    THEN 'Transactions en cours (non committees)'
            WHEN 'UNEXPIRED' THEN 'Conserve (dans UNDO_RETENTION)'
            WHEN 'EXPIRED'   THEN 'Recyclable (hors retention)'
            ELSE 'Autre'
       END                                                        AS signification
  FROM dba_undo_extents e
 GROUP BY e.status
 ORDER BY SUM(e.bytes) DESC
;

PROMPT
PROMPT  Configuration UNDO :
PROMPT

-- -----------------------------------------------
-- 3. Parametres et configuration UNDO critiques
-- -----------------------------------------------

COL information FORMAT A45  HEAD "Information"
COL valeur      FORMAT A45  HEAD "Valeur"

SELECT 'UNDO_MANAGEMENT'                                          AS information
      ,UPPER(value)                                              AS valeur
  FROM v$parameter
 WHERE name = 'undo_management'
UNION ALL
SELECT 'UNDO_TABLESPACE actif'
      ,value
  FROM v$parameter
 WHERE name = 'undo_tablespace'
UNION ALL
SELECT 'UNDO_RETENTION (parametre)'
      ,TRIM(TO_CHAR(TO_NUMBER(value), '999,999')) || ' s ('
       || TRIM(TO_CHAR(ROUND(TO_NUMBER(value)/60), '999,999')) || ' min)'
  FROM v$parameter
 WHERE name = 'undo_retention'
UNION ALL
SELECT 'Retention auto-tunee (V$UNDOSTAT)'
      ,TRIM(TO_CHAR(MAX(tuned_undoretention), '999,999')) || ' s ('
       || TRIM(TO_CHAR(ROUND(MAX(tuned_undoretention)/60), '999,999')) || ' min)'
  FROM v$undostat
UNION ALL
SELECT 'RETENTION GUARANTEE'
      ,MAX(CASE WHEN ts.retention = 'GUARANTEE'
                THEN 'OUI (' || ts.tablespace_name || ' garanti)'
                ELSE 'NON (Oracle peut recycler l''UNDO)' END)
  FROM dba_tablespaces ts
 WHERE ts.contents = 'UNDO'
;

PROMPT
PROMPT  % Util = utilisation de la taille actuelle (allocation disque)
PROMPT  % Max  = utilisation de la capacite MAXIMALE (vrai risque ORA-30036)
PROMPT
PROMPT  % Max > 85% = !! CRITIQUE : capacite max bientot atteinte
PROMPT  % Max > 70% = Surveiller : planifier extension
PROMPT  ACTIVE      = transactions en cours (impossible a recycler)
PROMPT  UNEXPIRED   = protege par UNDO_RETENTION
PROMPT  ORA-01555   = snapshot too old (retention trop courte / UNDO recycle)
PROMPT  ORA-30036   = unable to extend (UNDO plein, souvent RETENTION GUARANTEE)
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_10
