-- ============================================================================
-- SCRIPT     : v_cf_record_sections.sql
-- MODULE     : M1.8 - Control Files
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_cf_record_sections.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== CF RECORD SECTIONS - UTILISATION INTERNE ====================
PROMPT

-- -----------------------------------------------
-- 1. Sections utilisees (records > 0)
-- -----------------------------------------------

COL type_sect FORMAT A28   HEAD "Section"
COL total     FORMAT 999,999 HEAD "Total"
COL utilise   FORMAT 999,999 HEAD "Utilises"
COL pct       FORMAT A8     HEAD "% Util"
COL nature    FORMAT A15    HEAD "Nature"
COL statut    FORMAT A15    HEAD "Statut"

SELECT type                                                      AS type_sect
      ,records_total                                             AS total
      ,records_used                                              AS utilise
      ,LPAD(TRIM(TO_CHAR(
          ROUND(records_used * 100 / NULLIF(records_total, 0), 1)
          , '990.0')) || '%', 7)                                 AS pct
      ,CASE WHEN type IN ('ARCHIVED LOG', 'BACKUP PIECE', 'BACKUP DATAFILE',
                          'BACKUP REDOLOG', 'BACKUP SPFILE', 'BACKUP CORRUPTION',
                          'DATAFILE COPY', 'OFFLINE RANGE', 'PROXY COPY',
                          'PROXY COPY CORRUPTION', 'FOREIGN ARCHIVED LOG',
                          'BACKUP SET', 'LOG HISTORY', 'DELETED OBJECT',
                          'RMAN STATUS')
            THEN 'Circulaire'
            ELSE 'Permanente'
       END                                                       AS nature
      ,CASE
            -- Sections circulaires : alerte sur risque ecrasement records
            WHEN type IN ('ARCHIVED LOG', 'BACKUP PIECE', 'BACKUP DATAFILE',
                          'BACKUP REDOLOG', 'BACKUP SPFILE', 'BACKUP CORRUPTION',
                          'DATAFILE COPY', 'OFFLINE RANGE', 'PROXY COPY',
                          'PROXY COPY CORRUPTION', 'FOREIGN ARCHIVED LOG',
                          'BACKUP SET', 'LOG HISTORY', 'DELETED OBJECT',
                          'RMAN STATUS')
                 AND records_total > 0
                 AND records_used * 100 / records_total > 90
            THEN '!! CRITIQUE'
            WHEN type IN ('ARCHIVED LOG', 'BACKUP PIECE', 'BACKUP DATAFILE',
                          'BACKUP REDOLOG', 'BACKUP SPFILE', 'BACKUP CORRUPTION',
                          'DATAFILE COPY', 'OFFLINE RANGE', 'PROXY COPY',
                          'PROXY COPY CORRUPTION', 'FOREIGN ARCHIVED LOG',
                          'BACKUP SET', 'LOG HISTORY', 'DELETED OBJECT',
                          'RMAN STATUS')
                 AND records_total > 0
                 AND records_used * 100 / records_total > 75
            THEN 'Surveiller'
            -- Sections permanentes : alerte seulement si croissance anormale
            WHEN type IN ('DATAFILE', 'TABLESPACE', 'REDO LOG', 'REDO THREAD',
                          'TEMPORARY FILENAME', 'FILENAME')
                 AND records_total > 0
                 AND records_used * 100 / records_total > 90
            THEN 'Surveiller'
            -- Sections systeme (DATABASE, STANDBY MATRIX, etc.) : 100% = normal
            ELSE 'OK'
       END                                                       AS statut
  FROM v$controlfile_record_section
 WHERE records_used > 0
 ORDER BY records_used * 100 / NULLIF(records_total, 1) DESC
;

PROMPT
PROMPT  Parametre CONTROL_FILE_RECORD_KEEP_TIME :
PROMPT

-- -----------------------------------------------
-- 2. Parametre KEEP_TIME (retention RMAN)
-- -----------------------------------------------

COL parametre   FORMAT A40  HEAD "Parametre"
COL valeur_par  FORMAT A20  HEAD "Valeur"
COL diagnostic  FORMAT A50  HEAD "Diagnostic"

SELECT name                                                      AS parametre
      ,value                                                     AS valeur_par
      ,CASE WHEN TO_NUMBER(value) = 0
            THEN '!! DANGER : RMAN perd les references backup'
            WHEN TO_NUMBER(value) < 7
            THEN 'Court : verifier strategie backup RMAN'
            WHEN TO_NUMBER(value) BETWEEN 7 AND 30
            THEN 'OK (recommande : 7-30 jours)'
            ELSE 'Long : verifier impact CF size'
       END                                                       AS diagnostic
  FROM v$parameter
 WHERE name = 'control_file_record_keep_time'
;

PROMPT
PROMPT  Actions :
PROMPT  Section circulaire > 90%      --> Augmenter CONTROL_FILE_RECORD_KEEP_TIME
PROMPT  Section permanente > 90%      --> Verifier croissance anormale (datafiles, redo)
PROMPT  KEEP_TIME = 0                 --> RMAN perd la trace des backups
PROMPT  CF section pleine            --> ORA-00245 ou Oracle agrandit le CF
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_8
