-- ============================================================================
-- SCRIPT     : v_synonymes_acces.sql
-- MODULE     : M1.11 - Schemas et Utilisateurs Oracle
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_synonymes_acces.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ============== SYNONYMES ET ACCES CROSS-SCHEMA (DIAG ORA-00942) ==============
PROMPT

-- -----------------------------------------------
-- 1. Contexte de la session : qui suis-je, ou suis-je
-- -----------------------------------------------

COL information FORMAT A45  HEAD "Contexte de la session"
COL valeur      FORMAT A45  HEAD "Valeur"

SELECT 'Utilisateur connecte (USER)'                              AS information
      ,USER                                                       AS valeur
  FROM dual
UNION ALL
SELECT 'Utilisateur authentifie (SESSION_USER)'
      ,SYS_CONTEXT('USERENV', 'SESSION_USER')
  FROM dual
UNION ALL
SELECT 'Schema courant (CURRENT_SCHEMA)'
      ,SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
  FROM dual
UNION ALL
SELECT 'Base de donnees (DB_NAME)'
      ,SYS_CONTEXT('USERENV', 'DB_NAME')
  FROM dual
UNION ALL
SELECT 'Container courant (CON_NAME)'
      ,SYS_CONTEXT('USERENV', 'CON_NAME')
  FROM dual
;

PROMPT
PROMPT  Synonymes publics sans aucun GRANT (cause numero 1 d'ORA-00942) :
PROMPT

-- -----------------------------------------------
-- 2. Le synonyme existe, la table existe, et pourtant ORA-00942
-- -----------------------------------------------

COL synonyme     FORMAT A28  HEAD "Synonyme public"
COL schema_cible FORMAT A18  HEAD "Schema cible"
COL objet_cible  FORMAT A30  HEAD "Objet cible"
COL diagnostic   FORMAT A44  HEAD "Diagnostic"

WITH sans_grant AS (
    SELECT s.synonym_name, s.table_owner, s.table_name
      FROM dba_synonyms s
      JOIN dba_users u ON u.username = s.table_owner
                      AND u.oracle_maintained = 'N'
     WHERE s.owner = 'PUBLIC'
       AND s.db_link IS NULL
       AND NOT EXISTS (SELECT 1 FROM dba_tab_privs p
                        WHERE p.owner = s.table_owner
                          AND p.table_name = s.table_name)
)
SELECT synonyme, schema_cible, objet_cible, diagnostic
  FROM (
    SELECT g.synonym_name                                         AS synonyme
          ,g.table_owner                                          AS schema_cible
          ,g.table_name                                           AS objet_cible
          ,'!! ORA-00942 pour tous sauf le proprietaire'          AS diagnostic
      FROM sans_grant g
     ORDER BY g.table_owner, g.synonym_name
  )
 WHERE ROWNUM <= 20
UNION ALL
SELECT '-', '-', 'Aucun synonyme sans GRANT', 'OK : rien a corriger'
  FROM dual
 WHERE NOT EXISTS (SELECT 1 FROM sans_grant)
;

PROMPT
PROMPT  Synonymes orphelins : la cible n'existe plus (ORA-00980) :
PROMPT

-- -----------------------------------------------
-- 3. Synonymes pointant vers un objet ou un schema supprime
-- -----------------------------------------------

COL proprietaire FORMAT A16  HEAD "Proprietaire"
COL synonyme     FORMAT A26  HEAD "Synonyme"
COL cible        FORMAT A40  HEAD "Cible declaree (inexistante)"
COL action       FORMAT A44  HEAD "Action"

WITH orphelins AS (
    SELECT s.owner, s.synonym_name, s.table_owner, s.table_name
      FROM dba_synonyms s
     WHERE s.db_link IS NULL
       AND s.table_owner NOT IN (SELECT username FROM dba_users
                                  WHERE oracle_maintained = 'Y')
       AND NOT EXISTS (SELECT 1 FROM dba_objects o
                        WHERE o.owner = s.table_owner
                          AND o.object_name = s.table_name)
)
SELECT proprietaire, synonyme, cible, action
  FROM (
    SELECT o.owner                                                AS proprietaire
          ,o.synonym_name                                         AS synonyme
          ,o.table_owner || '.' || o.table_name                   AS cible
          ,'!! ORA-00980 : DROP SYNONYM ou recreer'               AS action
      FROM orphelins o
     ORDER BY o.owner, o.synonym_name
  )
 WHERE ROWNUM <= 20
UNION ALL
SELECT '-', '-', 'Aucun synonyme orphelin', 'OK : toutes les cibles existent'
  FROM dual
 WHERE NOT EXISTS (SELECT 1 FROM orphelins)
;

PROMPT
PROMPT  Synthese des synonymes par schema cible :
PROMPT

-- -----------------------------------------------
-- 4. Synthese par schema cible
--    Une ligne par schema, jamais par synonyme : une application qui cree
--    un synonyme public par table tient sur UNE ligne.
-- -----------------------------------------------

COL schema_cible FORMAT A20     HEAD "Schema cible"
COL nb_total     FORMAT 999,999 HEAD "Synonymes"
COL nb_publics   FORMAT 999,999 HEAD "Publics"
COL nb_prives    FORMAT 999,999 HEAD "Prives"
COL nb_orphelins FORMAT 999,999 HEAD "Orphelins"
COL verdict      FORMAT A42     HEAD "Verdict"

WITH syn AS (
    SELECT s.owner, s.table_owner, s.table_name
          ,CASE WHEN EXISTS (SELECT 1 FROM dba_objects o
                              WHERE o.owner       = s.table_owner
                                AND o.object_name = s.table_name)
                THEN 0 ELSE 1
           END                                                    AS orphelin
      FROM dba_synonyms s
     WHERE s.db_link IS NULL
       AND s.table_owner NOT IN (SELECT username FROM dba_users
                                  WHERE oracle_maintained = 'Y')
)
SELECT table_owner                                                AS schema_cible
      ,COUNT(*)                                                   AS nb_total
      ,SUM(CASE WHEN owner = 'PUBLIC' THEN 1 ELSE 0 END)          AS nb_publics
      ,SUM(CASE WHEN owner = 'PUBLIC' THEN 0 ELSE 1 END)          AS nb_prives
      ,SUM(orphelin)                                              AS nb_orphelins
      ,CASE
            WHEN SUM(orphelin) > 0
            THEN '!! ' || TRIM(TO_CHAR(SUM(orphelin), '999,999'))
                 || ' synonyme(s) pointant dans le vide'
            WHEN SUM(CASE WHEN owner = 'PUBLIC' THEN 1 ELSE 0 END) > 0
            THEN 'Synonymes publics : verifier les GRANT'
            ELSE 'OK'
       END                                                        AS verdict
  FROM syn
 GROUP BY table_owner
 ORDER BY COUNT(*) DESC
;

PROMPT
PROMPT  Un synonyme ne donne aucun droit : il traduit un nom. Sans GRANT = ORA-00942.
PROMPT
PROMPT  Diagnostic ORA-00942 (ajouter le point-virgule final a chaque ligne) :
PROMPT  1. SELECT owner, table_name FROM dba_tables WHERE table_name = 'MA_TABLE'
PROMPT  2. SELECT SYS_CONTEXT('USERENV','CURRENT_SCHEMA') FROM dual
PROMPT  3. SELECT COUNT(*) FROM proprietaire.ma_table
PROMPT  4. GRANT SELECT ON proprietaire.ma_table TO compte_appli
PROMPT
PROMPT  ORA-00942 droit manquant  |  ORA-00980 cible supprimee  |  ORA-01775 boucle
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_11
