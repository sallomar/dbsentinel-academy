-- ============================================================================
-- SCRIPT     : v_temp_sizing.sql
-- MODULE     : M1.9 - TEMP Tablespace
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_temp_sizing.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== TEMP - SIZING ET RECOMMANDATIONS ====================
PROMPT

-- -----------------------------------------------
-- 1. Parametres de reference (PGA, parallelism)
-- -----------------------------------------------

COL parametre  FORMAT A40  HEAD "Parametre"
COL valeur_par FORMAT A25  HEAD "Valeur"
COL impact     FORMAT A50  HEAD "Impact sur TEMP"

SELECT 'PGA_AGGREGATE_TARGET'                                    AS parametre
      ,TRIM(TO_CHAR(TO_NUMBER(value)/1073741824, '999,999.9')) || ' GB' AS valeur_par
      ,'Memoire PGA disponible pour tris'                        AS impact
  FROM v$parameter
 WHERE name = 'pga_aggregate_target'
UNION ALL
SELECT 'PGA_AGGREGATE_LIMIT'
      ,TRIM(TO_CHAR(TO_NUMBER(value)/1073741824, '999,999.9')) || ' GB'
      ,'Limite max PGA (Oracle 12c+)'
  FROM v$parameter
 WHERE name = 'pga_aggregate_limit'
UNION ALL
SELECT 'PARALLEL_MAX_SERVERS'
      ,TRIM(TO_CHAR(TO_NUMBER(value), '999,999'))
      ,'Multiplicateur potentiel TEMP par session'
  FROM v$parameter
 WHERE name = 'parallel_max_servers'
UNION ALL
SELECT 'WORKAREA_SIZE_POLICY'
      ,value
      ,'AUTO = Oracle gere - MANUAL = parametres fixes'
  FROM v$parameter
 WHERE name = 'workarea_size_policy'
;

PROMPT
PROMPT  Comparaison TEMP actuel vs recommande :
PROMPT

-- -----------------------------------------------
-- 2. Calcul recommandation taille TEMP
-- -----------------------------------------------

COL element       FORMAT A40  HEAD "Element"
COL valeur_calc   FORMAT A30  HEAD "Valeur"
COL recommandation FORMAT A50 HEAD "Recommandation"

WITH params AS (
    SELECT MAX(CASE WHEN name = 'pga_aggregate_target' THEN TO_NUMBER(value) END) AS pga_target
          ,MAX(CASE WHEN name = 'parallel_max_servers' THEN TO_NUMBER(value) END) AS parallel_max
      FROM v$parameter
     WHERE name IN ('pga_aggregate_target', 'parallel_max_servers')
),
temp_alloc AS (
    SELECT SUM(bytes)         AS current_bytes
          ,SUM(CASE WHEN autoextensible = 'YES'
                    THEN maxbytes ELSE bytes END) AS max_bytes
      FROM dba_temp_files
)
SELECT 'TEMP actuellement alloue'                                AS element
      ,LPAD(TRIM(TO_CHAR(t.current_bytes/1073741824, '999,999.9')) || ' GB', 12) AS valeur_calc
      ,'-'                                                       AS recommandation
  FROM temp_alloc t
UNION ALL
SELECT 'TEMP max (avec AUTOEXTEND)'
      ,LPAD(TRIM(TO_CHAR(t.max_bytes/1073741824, '999,999.9')) || ' GB', 12)
      ,'-'
  FROM temp_alloc t
UNION ALL
SELECT 'TEMP recommande minimum (2 x PGA)'
      ,LPAD(TRIM(TO_CHAR(p.pga_target * 2 / 1073741824, '999,999.9')) || ' GB', 12)
      ,CASE WHEN t.max_bytes >= p.pga_target * 2
            THEN 'OK : capacite max suffisante'
            ELSE '!! Etendre TEMP ou augmenter MAXSIZE'
       END
  FROM params p, temp_alloc t
UNION ALL
SELECT 'TEMP recommande optimal (3 x PGA)'
      ,LPAD(TRIM(TO_CHAR(p.pga_target * 3 / 1073741824, '999,999.9')) || ' GB', 12)
      ,CASE WHEN t.max_bytes >= p.pga_target * 3
            THEN 'OK : optimal'
            ELSE 'A AMELIORER : envisager extension'
       END
  FROM params p, temp_alloc t
UNION ALL
SELECT 'TEMP avec parallelism (3 x PGA x DOP/8)'
      ,CASE WHEN p.parallel_max > 0
            THEN LPAD(TRIM(TO_CHAR(p.pga_target * 3 * p.parallel_max / 8 / 1073741824, '999,999.9')) || ' GB', 12)
            ELSE LPAD('N/A', 12)
       END
      ,CASE WHEN p.parallel_max > 0
            THEN 'Si traitements paralleles intensifs'
            ELSE 'Parallelism desactive (DOP = 0)'
       END
  FROM params p, temp_alloc t
;

PROMPT
PROMPT  Statistiques PGA + tris (depuis startup) :
PROMPT

-- -----------------------------------------------
-- 3. Indicateurs cles PGA
-- -----------------------------------------------

COL indicateur  FORMAT A40  HEAD "Indicateur PGA"
COL valeur_ind  FORMAT A25  HEAD "Valeur"

SELECT name                                                      AS indicateur
      ,CASE WHEN unit = 'bytes'
            THEN LPAD(TRIM(TO_CHAR(value/1048576, '999,999.9')) || ' MB', 14)
            ELSE LPAD(TRIM(TO_CHAR(value, '999,999,999,999')), 14)
       END                                                       AS valeur_ind
  FROM v$pgastat
 WHERE name IN (
    'aggregate PGA target parameter'
   ,'total PGA allocated'
   ,'maximum PGA allocated'
   ,'over allocation count'
   ,'extra bytes read/written'
   ,'cache hit percentage'
 )
;

PROMPT
PROMPT  Regle d'or sizing TEMP :
PROMPT  TEMP minimum  = 2 x PGA_AGGREGATE_TARGET
PROMPT  TEMP optimal  = 3 x PGA_AGGREGATE_TARGET
PROMPT  TEMP parallel = 3 x PGA x (PARALLEL_MAX_SERVERS / 8)
PROMPT  AUTOEXTEND ON obligatoire en production
PROMPT  Plusieurs tempfiles --> meilleure repartition I/O
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_9
