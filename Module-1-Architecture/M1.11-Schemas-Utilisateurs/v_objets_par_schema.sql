-- ============================================================================
-- SCRIPT     : v_objets_par_schema.sql
-- MODULE     : M1.11 - Schemas et Utilisateurs Oracle
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_objets_par_schema.sql
-- ============================================================================
-- NOTE       : est applicatif ce qui appartient a un compte non livre par
--              Oracle. Le filtre porte sur DBA_USERS, jamais sur la colonne
--              ORACLE_MAINTAINED de DBA_OBJECTS : Oracle cree lui-meme des
--              milliers d'objets marques N (DataPump, AWR, Java, contextes).
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== CARTOGRAPHIE DES OBJETS PAR SCHEMA ====================
PROMPT
PROMPT  Schemas applicatifs uniquement (schemas Oracle exclus)
PROMPT

-- -----------------------------------------------
-- 1. Repartition des objets par schema et par type
-- -----------------------------------------------

COL proprietaire FORMAT A18    HEAD "Schema"
COL nb_tables    FORMAT 99,999 HEAD "Tables"
COL nb_index     FORMAT 99,999 HEAD "Index"
COL nb_vues      FORMAT 9,999  HEAD "Vues"
COL nb_seq       FORMAT 9,999  HEAD "Seq"
COL nb_plsql     FORMAT 9,999  HEAD "PL/SQL"
COL nb_trig      FORMAT 9,999  HEAD "Trig"
COL nb_syn       FORMAT 9,999  HEAD "Syn"
COL nb_autres    FORMAT 9,999  HEAD "Autres"
COL nb_total     FORMAT 99,999 HEAD "Total"
COL nb_invalid   FORMAT 9,999  HEAD "INVALID"

SELECT o.owner                                                    AS proprietaire
      ,COUNT(CASE WHEN o.object_type = 'TABLE'    THEN 1 END)     AS nb_tables
      ,COUNT(CASE WHEN o.object_type = 'INDEX'    THEN 1 END)     AS nb_index
      ,COUNT(CASE WHEN o.object_type = 'VIEW'     THEN 1 END)     AS nb_vues
      ,COUNT(CASE WHEN o.object_type = 'SEQUENCE' THEN 1 END)     AS nb_seq
      ,COUNT(CASE WHEN o.object_type IN ('PROCEDURE','FUNCTION','PACKAGE',
                                          'PACKAGE BODY','TYPE','TYPE BODY')
                  THEN 1 END)                                     AS nb_plsql
      ,COUNT(CASE WHEN o.object_type = 'TRIGGER'  THEN 1 END)     AS nb_trig
      ,COUNT(CASE WHEN o.object_type = 'SYNONYM'  THEN 1 END)     AS nb_syn
      ,COUNT(CASE WHEN o.object_type NOT IN ('TABLE','INDEX','VIEW','SEQUENCE',
                                              'PROCEDURE','FUNCTION','PACKAGE',
                                              'PACKAGE BODY','TYPE','TYPE BODY',
                                              'TRIGGER','SYNONYM')
                  THEN 1 END)                                     AS nb_autres
      ,COUNT(*)                                                   AS nb_total
      ,COUNT(CASE WHEN o.status = 'INVALID' THEN 1 END)           AS nb_invalid
  FROM dba_objects o
 WHERE o.owner IN (SELECT username FROM dba_users
                    WHERE oracle_maintained = 'N')
 GROUP BY o.owner
 ORDER BY COUNT(*) DESC
;

PROMPT
PROMPT  Objets INVALID (20 premiers ; total par schema dans la colonne INVALID) :
PROMPT

-- -----------------------------------------------
-- 2. Objets INVALID : ce qui casse apres un deploiement
-- -----------------------------------------------

COL proprietaire FORMAT A18  HEAD "Schema"
COL objet        FORMAT A30  HEAD "Objet"
COL type_obj     FORMAT A16  HEAD "Type"
COL derniere_ddl FORMAT A18  HEAD "Derniere DDL"
COL action       FORMAT A32  HEAD "Action"

WITH inv AS (
    SELECT o.owner, o.object_name, o.object_type, o.last_ddl_time
      FROM dba_objects o
     WHERE o.owner IN (SELECT username FROM dba_users
                        WHERE oracle_maintained = 'N')
       AND o.status = 'INVALID'
)
SELECT proprietaire, objet, type_obj, derniere_ddl, action
  FROM (
    SELECT i.owner                                                AS proprietaire
          ,i.object_name                                          AS objet
          ,i.object_type                                          AS type_obj
          ,TO_CHAR(i.last_ddl_time, 'DD/MM/YYYY HH24:MI')         AS derniere_ddl
          ,CASE i.object_type
                WHEN 'PACKAGE BODY' THEN 'ALTER PACKAGE ... COMPILE BODY'
                WHEN 'VIEW'         THEN 'ALTER VIEW ... COMPILE'
                WHEN 'TRIGGER'      THEN 'ALTER TRIGGER ... COMPILE'
                ELSE 'UTL_RECOMP.RECOMP_SERIAL'
           END                                                    AS action
      FROM inv i
     ORDER BY i.owner, i.object_name
  )
 WHERE ROWNUM <= 20
UNION ALL
SELECT '-', 'Aucun objet INVALID', '-', '-', 'OK : rien a recompiler'
  FROM dual
 WHERE NOT EXISTS (SELECT 1 FROM inv)
;

PROMPT
PROMPT  Objets applicatifs mal places :
PROMPT

-- -----------------------------------------------
-- 3. Objets applicatifs hors de leur place
-- -----------------------------------------------

COL proprietaire FORMAT A18  HEAD "Schema"
COL objet        FORMAT A32  HEAD "Objet"
COL type_obj     FORMAT A16  HEAD "Type"
COL localisation FORMAT A20  HEAD "Localisation"
COL risque       FORMAT A38  HEAD "Constat"

WITH mal_places AS (
    -- (a) Objets d'un compte applicatif stockes dans SYSTEM ou SYSAUX
    SELECT s.owner                                                AS proprietaire
          ,s.segment_name                                         AS objet
          ,s.segment_type                                         AS type_obj
          ,'Tablespace ' || s.tablespace_name                     AS localisation
          ,'!! Sature SYSTEM : risque ORA-01653'                  AS risque
      FROM dba_segments s
     WHERE s.owner IN (SELECT username FROM dba_users
                        WHERE oracle_maintained = 'N')
       AND s.tablespace_name IN ('SYSTEM', 'SYSAUX')
    UNION ALL
    -- (b) Objets metier crees dans SYS ou SYSTEM
    --     Deux regles sur la FORME du nom, pas une liste d'exclusions :
    --     1) un nom humain ne contient que des lettres, chiffres et underscore.
    --        Oracle genere des noms avec $ # + = - / (nested tables, AQ, AWR).
    --     2) exclusion des familles Oracle a nom propre (SYSNT, QT<n>, UTL_...)
    SELECT o.owner
          ,o.object_name
          ,o.object_type
          ,'Schema ' || o.owner
          ,'!! Perdu au prochain upgrade Oracle'
      FROM dba_objects o
     WHERE o.owner IN ('SYS', 'SYSTEM')
       AND o.oracle_maintained = 'N'
       AND o.object_type IN ('TABLE','VIEW','SEQUENCE','MATERIALIZED VIEW',
                             'PACKAGE','PACKAGE BODY','PROCEDURE','FUNCTION',
                             'TRIGGER')
       AND REGEXP_LIKE(o.object_name, '^[A-Z][A-Z0-9_]*$', 'c')
       AND NOT REGEXP_LIKE(o.object_name,
               '^(SYSNT|SYSTP|SYS_|QT[0-9]|KUPC|KUPD|UTL_|DBMS_|LOGMNR|MVIEW|'
            || 'ODCI|HS_|MV_RF|SCHEDULER|AQ[0-9$]|WRH|WRI|WRM|WRR)', 'c')
    UNION ALL
    -- (c) Tables de controle DataPump laissees apres un import/export
    SELECT o.owner
          ,o.object_name
          ,o.object_type
          ,'Schema ' || o.owner
          ,'Reste d''un DataPump : DROP possible'
      FROM dba_objects o
     WHERE o.object_type = 'TABLE'
       AND (o.object_name LIKE 'SYS\_IMPORT\_%' ESCAPE '\'
         OR o.object_name LIKE 'SYS\_EXPORT\_%' ESCAPE '\')
)
SELECT proprietaire, objet, type_obj, localisation, risque
  FROM mal_places
UNION ALL
SELECT '-', 'Aucun objet applicatif mal place', '-', '-', 'OK : rien a corriger'
  FROM dual
 WHERE NOT EXISTS (SELECT 1 FROM mal_places)
 ORDER BY 1, 2
;

PROMPT
PROMPT  DDL des 30 derniers jours, hors jobs et partitions (15 dernieres) :
PROMPT

-- -----------------------------------------------
-- 4. Activite DDL recente (hors jobs et maintenance de partitions)
-- -----------------------------------------------

COL proprietaire FORMAT A18  HEAD "Schema"
COL objet        FORMAT A30  HEAD "Objet"
COL type_obj     FORMAT A16  HEAD "Type"
COL derniere_ddl FORMAT A18  HEAD "Derniere DDL"
COL creation     FORMAT A18  HEAD "Cree le"
COL etat         FORMAT A10  HEAD "Statut"

WITH ddl AS (
    SELECT o.owner, o.object_name, o.object_type
          ,o.last_ddl_time, o.created, o.status
      FROM dba_objects o
     WHERE o.owner IN (SELECT username FROM dba_users
                        WHERE oracle_maintained = 'N')
       AND o.last_ddl_time > SYSDATE - 30
       AND o.object_type NOT IN ('JOB','SCHEDULE','PROGRAM','WINDOW',
                                 'TABLE PARTITION','INDEX PARTITION',
                                 'TABLE SUBPARTITION','INDEX SUBPARTITION',
                                 'LOB','LOB PARTITION')
)
SELECT proprietaire, objet, type_obj, derniere_ddl, creation, etat
  FROM (
    SELECT d.owner                                                AS proprietaire
          ,d.object_name                                          AS objet
          ,d.object_type                                          AS type_obj
          ,TO_CHAR(d.last_ddl_time, 'DD/MM/YYYY HH24:MI')         AS derniere_ddl
          ,TO_CHAR(d.created, 'DD/MM/YYYY HH24:MI')               AS creation
          ,d.status                                               AS etat
      FROM ddl d
     ORDER BY d.last_ddl_time DESC
  )
 WHERE ROWNUM <= 15
UNION ALL
SELECT '-', 'Aucune DDL depuis 30 jours', '-', '-', '-', 'OK'
  FROM dual
 WHERE NOT EXISTS (SELECT 1 FROM ddl)
;

PROMPT
PROMPT  Est applicatif ce qui appartient a un compte non livre par Oracle.
PROMPT  INVALID = objet a recompiler, pas objet perdu.
PROMPT  Objet metier dans SYS/SYSTEM = supprime au prochain upgrade Oracle.
PROMPT
PROMPT  ORA-04068 package recompile  |  ORA-01653 tablespace SYSTEM sature
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_11
