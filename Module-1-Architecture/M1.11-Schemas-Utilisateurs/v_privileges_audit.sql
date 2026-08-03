-- ============================================================================
-- SCRIPT     : v_privileges_audit.sql
-- MODULE     : M1.11 - Schemas et Utilisateurs Oracle
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_privileges_audit.sql
-- ============================================================================
-- NOTE       : une ligne par beneficiaire, jamais une ligne par privilege.
--              Un compte a qui on a accorde 150 privileges systeme tient sur
--              une ligne : le DBA a besoin du verdict, pas de la liste.
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== AUDIT DES PRIVILEGES ET DES ROLES ====================
PROMPT
PROMPT  Comptes et roles applicatifs (comptes internes Oracle exclus)
PROMPT

-- -----------------------------------------------
-- 1. Privileges systeme sensibles, agreges par beneficiaire
-- -----------------------------------------------

COL beneficiaire FORMAT A20     HEAD "Beneficiaire"
COL nature       FORMAT A7      HEAD "Type"
COL nb_sensibles FORMAT 999,999 HEAD "Sensibles"
COL nb_critiques FORMAT 999,999 HEAD "Critiques"
COL admin_opt    FORMAT A6      HEAD "ADMIN"
COL principaux   FORMAT A38     HEAD "Principaux privileges"
COL verdict      FORMAT A34     HEAD "Verdict"

WITH p AS (
    SELECT sp.grantee
          ,sp.privilege
          ,sp.admin_option
          -- rang 1 = privilege qui donne la main sur les donnees ou l'instance
          ,CASE WHEN sp.privilege IN ('SELECT ANY TABLE','DELETE ANY TABLE',
                                      'DROP ANY TABLE','ALTER ANY TABLE',
                                      'CREATE ANY TABLE','GRANT ANY PRIVILEGE',
                                      'GRANT ANY ROLE','ALTER SYSTEM','BECOME USER',
                                      'CREATE ANY PROCEDURE','EXECUTE ANY PROCEDURE')
                THEN 1 ELSE 2
           END                                                    AS rang
      FROM dba_sys_privs sp
     WHERE (sp.privilege LIKE '%ANY%'
            OR sp.privilege IN ('UNLIMITED TABLESPACE','ALTER SYSTEM','ALTER DATABASE',
                                'BECOME USER','CREATE USER','DROP USER','AUDIT SYSTEM'))
       AND sp.grantee NOT IN (SELECT username FROM dba_users
                               WHERE oracle_maintained = 'Y')
       AND sp.grantee NOT IN (SELECT role FROM dba_roles
                               WHERE oracle_maintained = 'Y')
),
tete AS (
    -- Les 2 privileges les plus graves, pour illustrer sans tout lister
    SELECT grantee
          ,LISTAGG(privilege, ', ') WITHIN GROUP (ORDER BY rang, privilege) AS principaux
      FROM (SELECT grantee, privilege, rang
                  ,ROW_NUMBER() OVER (PARTITION BY grantee
                                          ORDER BY rang, privilege)  AS rn
              FROM p)
     WHERE rn <= 2
     GROUP BY grantee
)
SELECT p.grantee                                                  AS beneficiaire
      ,CASE WHEN p.grantee = 'PUBLIC'   THEN 'PUBLIC'
            WHEN r.role IS NOT NULL     THEN 'ROLE'
            ELSE 'USER'
       END                                                        AS nature
      ,COUNT(*)                                                   AS nb_sensibles
      ,SUM(CASE p.rang WHEN 1 THEN 1 ELSE 0 END)                  AS nb_critiques
      ,MAX(CASE WHEN p.admin_option = 'YES' THEN 'OUI' ELSE '-' END) AS admin_opt
      ,SUBSTR(MAX(t.principaux), 1, 38)                           AS principaux
      ,CASE
            WHEN p.grantee = 'PUBLIC'
            THEN '!! Accorde a TOUS les comptes'
            WHEN SUM(CASE p.rang WHEN 1 THEN 1 ELSE 0 END) >= 5
            THEN '!! Pouvoir equivalent DBA'
            WHEN SUM(CASE p.rang WHEN 1 THEN 1 ELSE 0 END) >= 1
            THEN '!! Privileges critiques accordes'
            -- UNLIMITED TABLESPACE seul : c'est un quota ignore, pas une portee
            WHEN COUNT(*) = SUM(CASE WHEN p.privilege = 'UNLIMITED TABLESPACE'
                                     THEN 1 ELSE 0 END)
            THEN 'Quota ignore (voir check_schemas)'
            ELSE 'A revoir : portee hors du schema'
       END                                                        AS verdict
  FROM p
  LEFT JOIN dba_roles r ON r.role    = p.grantee
  LEFT JOIN tete      t ON t.grantee = p.grantee
 GROUP BY p.grantee, r.role
 ORDER BY SUM(CASE p.rang WHEN 1 THEN 1 ELSE 0 END) DESC, COUNT(*) DESC
;

PROMPT
PROMPT  Roles accordes aux comptes applicatifs :
PROMPT

-- -----------------------------------------------
-- 2. Roles accordes (le pouvoir se cache souvent dans un role)
-- -----------------------------------------------

COL beneficiaire FORMAT A20  HEAD "Beneficiaire"
COL nature       FORMAT A6   HEAD "Type"
COL role_accorde FORMAT A26  HEAD "Role accorde"
COL admin_opt    FORMAT A6   HEAD "ADMIN"
COL par_defaut   FORMAT A7   HEAD "Defaut"
COL criticite    FORMAT A16  HEAD "Criticite"
COL portee       FORMAT A40  HEAD "Portee du role"

SELECT rp.grantee                                                 AS beneficiaire
      ,NVL2(r.role, 'ROLE', 'USER')                               AS nature
      ,rp.granted_role                                            AS role_accorde
      ,rp.admin_option                                            AS admin_opt
      ,rp.default_role                                            AS par_defaut
      ,CASE
            WHEN rp.granted_role IN ('DBA','PDB_DBA','SYSDBA')
            THEN '!! CRITIQUE'
            WHEN rp.granted_role IN ('IMP_FULL_DATABASE','EXP_FULL_DATABASE',
                                     'DATAPUMP_IMP_FULL_DATABASE','AUDIT_ADMIN')
            THEN '!! ELEVE'
            WHEN rp.granted_role IN ('RESOURCE','SELECT_CATALOG_ROLE')
            THEN 'A revoir'
            WHEN ro.oracle_maintained = 'N'
            THEN 'Role applicatif'
            ELSE 'Normal'
       END                                                        AS criticite
      ,CASE rp.granted_role
            WHEN 'DBA'                 THEN 'Pouvoir total sur la base de donnees'
            WHEN 'PDB_DBA'             THEN 'Pouvoir total sur la PDB'
            WHEN 'RESOURCE'            THEN 'Creation d''objets dans son schema'
            WHEN 'CONNECT'             THEN 'CREATE SESSION uniquement'
            WHEN 'SELECT_CATALOG_ROLE' THEN 'Lecture de tout le dictionnaire'
            WHEN 'IMP_FULL_DATABASE'   THEN 'Import complet : ecrit dans tout schema'
            WHEN 'EXP_FULL_DATABASE'   THEN 'Export complet : lit tout schema'
            ELSE 'Role interne : verifier son contenu'
       END                                                        AS portee
  FROM dba_role_privs rp
  LEFT JOIN dba_roles r  ON r.role  = rp.grantee
  LEFT JOIN dba_roles ro ON ro.role = rp.granted_role
 WHERE rp.grantee NOT IN (SELECT username FROM dba_users WHERE oracle_maintained = 'Y')
   AND rp.grantee NOT IN (SELECT role     FROM dba_roles WHERE oracle_maintained = 'Y')
 -- Les roles a pouvoir remontent en tete : CONNECT ne doit pas cacher un DBA
 ORDER BY CASE
            WHEN rp.granted_role IN ('DBA','PDB_DBA')                THEN 1
            WHEN rp.granted_role IN ('IMP_FULL_DATABASE','EXP_FULL_DATABASE',
                                     'DATAPUMP_IMP_FULL_DATABASE',
                                     'AUDIT_ADMIN')                  THEN 2
            WHEN rp.granted_role IN ('RESOURCE','SELECT_CATALOG_ROLE') THEN 3
            WHEN ro.oracle_maintained = 'N'                          THEN 4
            ELSE 5
          END
         ,rp.grantee, rp.granted_role
;

PROMPT
PROMPT  Droits accordes sur les objets d'un autre schema :
PROMPT

-- -----------------------------------------------
-- 3. Matrice des acces cross-schema
--    Une ligne par couple schema -> beneficiaire, jamais par objet.
-- -----------------------------------------------

COL proprietaire FORMAT A18     HEAD "Schema source"
COL beneficiaire FORMAT A22     HEAD "Beneficiaire"
COL nb_objets    FORMAT 999,999 HEAD "Objets"
COL droits       FORMAT A26     HEAD "Droits accordes"
COL alerte       FORMAT A22     HEAD "Alerte"

SELECT p.owner                                                    AS proprietaire
      ,p.grantee                                                  AS beneficiaire
      ,COUNT(DISTINCT p.table_name)                               AS nb_objets
      -- Un seul droit : on le nomme. Plusieurs : on compte et on dit l'essentiel.
      ,CASE WHEN COUNT(DISTINCT p.privilege) = 1
            THEN MIN(p.privilege)
            ELSE TRIM(TO_CHAR(COUNT(DISTINCT p.privilege), '999')) || ' droits'
                 || CASE WHEN MAX(CASE WHEN p.privilege IN ('INSERT','UPDATE',
                                                            'DELETE','ALTER','INDEX')
                                       THEN 1 ELSE 0 END) = 1
                         THEN ' (dont ecriture)'
                         ELSE ' (lecture)'
                    END
       END                                                        AS droits
      ,CASE
            WHEN p.grantee = 'PUBLIC'
            THEN '!! Accorde a PUBLIC'
            WHEN MAX(CASE WHEN p.grantable = 'YES' THEN 1 ELSE 0 END) = 1
            THEN '!! WITH GRANT OPTION'
            ELSE 'OK'
       END                                                        AS alerte
  FROM dba_tab_privs p
  JOIN dba_users u ON u.username = p.owner
                  AND u.oracle_maintained = 'N'
 WHERE p.grantee <> p.owner
 GROUP BY p.owner, p.grantee
 ORDER BY CASE WHEN p.grantee = 'PUBLIC' THEN 1 ELSE 2 END
         ,COUNT(DISTINCT p.table_name) DESC
         ,p.owner, p.grantee
;

PROMPT
PROMPT  Score de la revue de privileges :
PROMPT

-- -----------------------------------------------
-- 4. Synthese : la revue de privileges en 7 lignes
-- -----------------------------------------------

COL information FORMAT A50  HEAD "Indicateur"
COL valeur      FORMAT A10  HEAD "Valeur"
COL verdict     FORMAT A46  HEAD "Verdict"

SELECT 'Comptes avec un privilege ANY'                            AS information
      ,LPAD(TRIM(TO_CHAR(COUNT(DISTINCT p.grantee), '999,999')), 6) AS valeur
      ,CASE WHEN COUNT(DISTINCT p.grantee) > 0
            THEN '!! Revue necessaire : portee hors du schema'
            ELSE 'OK : aucun privilege transversal' END           AS verdict
  FROM dba_sys_privs p
  JOIN dba_users u ON u.username = p.grantee
                  AND u.oracle_maintained = 'N'
 WHERE p.privilege LIKE '%ANY%'
UNION ALL
SELECT 'Comptes avec UNLIMITED TABLESPACE'
      ,LPAD(TRIM(TO_CHAR(COUNT(DISTINCT p.grantee), '999,999')), 6)
      ,CASE WHEN COUNT(DISTINCT p.grantee) > 0
            THEN 'Les quotas sont ignores sur ces comptes'
            ELSE 'OK : les quotas sont respectes' END
  FROM dba_sys_privs p
  JOIN dba_users u ON u.username = p.grantee
                  AND u.oracle_maintained = 'N'
 WHERE p.privilege = 'UNLIMITED TABLESPACE'
UNION ALL
SELECT 'Role DBA accorde hors comptes Oracle'
      ,LPAD(TRIM(TO_CHAR(COUNT(*), '999,999')), 6)
      ,CASE WHEN COUNT(*) > 0
            THEN '!! CRITIQUE : pouvoir total accorde'
            ELSE 'OK : aucun DBA applicatif' END
  FROM dba_role_privs rp
  JOIN dba_users u ON u.username = rp.grantee
                  AND u.oracle_maintained = 'N'
 WHERE rp.granted_role = 'DBA'
UNION ALL
SELECT 'Objets applicatifs accessibles a PUBLIC'
      ,LPAD(TRIM(TO_CHAR(COUNT(DISTINCT p.owner || '.' || p.table_name),
                         '999,999')), 6)
      ,CASE WHEN COUNT(*) > 0
            THEN '!! Lisible par tous les comptes de la base'
            ELSE 'OK : aucun grant a PUBLIC' END
  FROM dba_tab_privs p
  JOIN dba_users u ON u.username = p.owner
                  AND u.oracle_maintained = 'N'
 WHERE p.grantee = 'PUBLIC'
UNION ALL
SELECT 'Objets delegables (WITH GRANT OPTION)'
      ,LPAD(TRIM(TO_CHAR(COUNT(DISTINCT p.owner || '.' || p.table_name),
                         '999,999')), 6)
      ,CASE WHEN COUNT(*) > 0
            THEN '!! Le beneficiaire peut re-accorder le droit'
            ELSE 'OK : aucune delegation de droits' END
  FROM dba_tab_privs p
  JOIN dba_users u ON u.username = p.owner
                  AND u.oracle_maintained = 'N'
 WHERE p.grantable = 'YES'
UNION ALL
SELECT 'Roles applicatifs definis (hors Oracle)'
      ,LPAD(TRIM(TO_CHAR(COUNT(*), '999,999')), 6)
      ,CASE WHEN COUNT(*) > 0
            THEN 'Verifier le contenu de chaque role'
            ELSE 'Aucun role applicatif : grants directs' END
  FROM dba_roles
 WHERE oracle_maintained = 'N'
UNION ALL
SELECT 'Roles applicatifs jamais accordes'
      ,LPAD(TRIM(TO_CHAR(COUNT(*), '999,999')), 6)
      ,CASE WHEN COUNT(*) > 0
            THEN 'Roles definis mais inutilises : a supprimer'
            ELSE 'OK : tous les roles sont accordes' END
  FROM dba_roles r
 WHERE r.oracle_maintained = 'N'
   AND NOT EXISTS (SELECT 1 FROM dba_role_privs rp
                    WHERE rp.granted_role = r.role)
;

PROMPT
PROMPT  ANY = le privilege porte sur TOUS les schemas, pas seulement le sien.
PROMPT  PUBLIC = tous les comptes de la base, y compris ceux crees demain.
PROMPT  Accorder les droits a un role, le role aux comptes : une seule revocation.
PROMPT
PROMPT  Descendre au detail d'une ligne (ajouter le point-virgule final) :
PROMPT  SELECT privilege FROM dba_sys_privs WHERE grantee = 'COMPTE' ORDER BY 1
PROMPT  SELECT table_name, privilege FROM dba_tab_privs
PROMPT   WHERE owner = 'SCHEMA' AND grantee = 'BENEFICIAIRE'
PROMPT
PROMPT  ORA-01031 privilege systeme manquant  |  ORA-00942 droit sur l'objet manquant
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_11
