-- ============================================================================
-- SCRIPT     : check_schemas.sql
-- MODULE     : M1.11 - Schemas et Utilisateurs Oracle
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @check_schemas.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ==================== COMPTES ET SCHEMAS - DIAGNOSTIC RAPIDE ====================
PROMPT
PROMPT  Comptes applicatifs (comptes internes Oracle exclus)
PROMPT

-- -----------------------------------------------
-- 1. Etat de chaque compte
-- -----------------------------------------------

COL compte      FORMAT A18  HEAD "Compte"
COL statut      FORMAT A18  HEAD "Statut du compte"
COL ts_defaut   FORMAT A18  HEAD "Tablespace defaut"
COL profil      FORMAT A14  HEAD "Profil"
COL creation    FORMAT A11  HEAD "Cree le"
COL derniere_cx FORMAT A11  HEAD "Dern. cnx"
COL alerte      FORMAT A30  HEAD "Alerte"

SELECT u.username                                                 AS compte
      ,u.account_status                                           AS statut
      ,u.default_tablespace                                       AS ts_defaut
      ,u.profile                                                  AS profil
      ,TO_CHAR(u.created, 'DD/MM/YYYY')                           AS creation
      ,NVL(TO_CHAR(CAST(u.last_login AS DATE), 'DD/MM/YYYY'), '-') AS derniere_cx
      ,CASE
            -- Un objet cree par ce compte atterrira dans SYSTEM
            WHEN u.default_tablespace IN ('SYSTEM', 'SYSAUX')
            THEN '!! Objets crees dans SYSTEM'
            -- Mot de passe expire mais periode de grace en cours
            WHEN u.account_status LIKE 'EXPIRED(GRACE)%'
            THEN '!! Mot de passe en sursis'
            WHEN u.account_status LIKE '%LOCKED%'
            THEN 'Compte verrouille'
            WHEN u.account_status LIKE 'EXPIRED%'
            THEN 'Mot de passe expire'
            WHEN u.last_login IS NULL
            THEN 'Jamais connecte'
            WHEN CAST(u.last_login AS DATE) < SYSDATE - 90
            THEN 'Inactif : plus de 90 jours'
            ELSE 'OK'
       END                                                        AS alerte
  FROM dba_users u
 WHERE u.oracle_maintained = 'N'
 ORDER BY u.username
;

PROMPT
PROMPT  Contenu et quota de chaque compte :
PROMPT

-- -----------------------------------------------
-- 2. Objets detenus + espace occupe + quota accorde
-- -----------------------------------------------

COL compte    FORMAT A18     HEAD "Compte"
COL nb_objets FORMAT 999,999 HEAD "Objets"
COL nb_tables FORMAT 999,999 HEAD "Tables"
COL occupe    FORMAT A12     HEAD "Occupe"
COL quota     FORMAT A18     HEAD "Quota"
COL verdict   FORMAT A38     HEAD "Verdict"

SELECT c.compte                                                   AS compte
      ,c.nb_objets                                                AS nb_objets
      ,c.nb_tables                                                AS nb_tables
      ,CASE WHEN c.mb >= 1024
            THEN LPAD(TRIM(TO_CHAR(c.mb/1024, '999,990.9')) || ' GB', 12)
            ELSE LPAD(TRIM(TO_CHAR(c.mb, '999,999')) || ' MB', 12)
       END                                                        AS occupe
      -- Quota accorde et taux de remplissage en une seule colonne
      ,CASE
            WHEN c.unlim IS NOT NULL  THEN 'ILLIMITE*'
            WHEN c.q_max = -1         THEN 'ILLIMITE'
            WHEN c.q_max IS NULL      THEN 'AUCUN'
            ELSE TRIM(TO_CHAR(c.q_max/1048576, '999,999')) || ' MB ('
                 || TRIM(TO_CHAR(ROUND(c.q_bytes * 100 / c.q_max, 1), '990.0'))
                 || '%)'
       END                                                        AS quota
      ,CASE
            -- Le risque n'est pas l'absence de quota, c'est le volume non borne
            WHEN c.unlim IS NOT NULL AND c.mb >= 10240
            THEN '!! ' || TRIM(TO_CHAR(c.mb/1024, '999,990.9'))
                 || ' GB sans quota : a encadrer'
            WHEN c.q_max > 0 AND c.q_bytes * 100 / c.q_max > 85
            THEN '!! Quota presque atteint (ORA-01536)'
            WHEN c.q_max > 0 AND c.q_bytes * 100 / c.q_max > 70
            THEN 'Surveiller le quota'
            -- Aucun quota ET des objets : le prochain CREATE echoue
            WHEN c.q_max IS NULL AND c.unlim IS NULL AND c.nb_objets > 0
            THEN '!! Aucun quota : CREATE TABLE bloque'
            -- Aucun quota ET aucun objet : compte de connexion, c'est normal
            WHEN c.q_max IS NULL AND c.unlim IS NULL
            THEN 'Compte de connexion (aucun objet)'
            ELSE 'OK'
       END                                                        AS verdict
  FROM (
    -- Un seul parcours de DBA_OBJECTS, DBA_TABLES et DBA_SEGMENTS,
    -- pas un par compte : le cout ne depend pas du nombre de schemas.
    SELECT u.username                                             AS compte
          ,NVL(o.nb_obj, 0)                                       AS nb_objets
          ,NVL(t.nb_tab, 0)                                       AS nb_tables
          ,NVL(s.mb, 0)                                           AS mb
          ,q.bytes                                                AS q_bytes
          ,q.max_bytes                                            AS q_max
          ,ut.grantee                                             AS unlim
      FROM dba_users u
      LEFT JOIN (SELECT owner, COUNT(*) AS nb_obj
                   FROM dba_objects GROUP BY owner) o
             ON o.owner = u.username
      LEFT JOIN (SELECT owner, COUNT(*) AS nb_tab
                   FROM dba_tables GROUP BY owner) t
             ON t.owner = u.username
      LEFT JOIN (SELECT owner, SUM(bytes)/1048576 AS mb
                   FROM dba_segments GROUP BY owner) s
             ON s.owner = u.username
      LEFT JOIN dba_ts_quotas q
             ON q.username        = u.username
            AND q.tablespace_name = u.default_tablespace
      LEFT JOIN (SELECT DISTINCT grantee
                   FROM dba_sys_privs
                  WHERE privilege = 'UNLIMITED TABLESPACE') ut
             ON ut.grantee = u.username
     WHERE u.oracle_maintained = 'N'
  ) c
 ORDER BY c.compte
;

PROMPT
PROMPT  Synthese :
PROMPT

-- -----------------------------------------------
-- 3. Synthese
-- -----------------------------------------------

COL information FORMAT A46  HEAD "Information"
COL valeur      FORMAT A32  HEAD "Valeur"

SELECT 'Comptes applicatifs'                                      AS information
      ,TRIM(TO_CHAR(COUNT(*), '999,999'))                         AS valeur
  FROM dba_users
 WHERE oracle_maintained = 'N'
UNION ALL
SELECT 'Comptes Oracle internes (exclus de ce rapport)'
      ,TRIM(TO_CHAR(COUNT(*), '999,999'))
  FROM dba_users
 WHERE oracle_maintained = 'Y'
UNION ALL
SELECT 'Comptes ouverts'
      ,TRIM(TO_CHAR(COUNT(*), '999,999'))
  FROM dba_users
 WHERE oracle_maintained = 'N'
   AND account_status = 'OPEN'
UNION ALL
SELECT 'Comptes verrouilles ou expires'
      ,TRIM(TO_CHAR(COUNT(*), '999,999'))
  FROM dba_users
 WHERE oracle_maintained = 'N'
   AND account_status <> 'OPEN'
UNION ALL
SELECT 'Comptes jamais connectes'
      ,TRIM(TO_CHAR(COUNT(*), '999,999'))
  FROM dba_users
 WHERE oracle_maintained = 'N'
   AND last_login IS NULL
UNION ALL
SELECT 'Comptes en espace illimite'
      ,TRIM(TO_CHAR(COUNT(DISTINCT p.grantee), '999,999'))
  FROM dba_sys_privs p
  JOIN dba_users u ON u.username = p.grantee
 WHERE p.privilege = 'UNLIMITED TABLESPACE'
   AND u.oracle_maintained = 'N'
UNION ALL
SELECT 'Comptes avec tablespace par defaut SYSTEM'
      ,TRIM(TO_CHAR(COUNT(*), '999,999'))
       || CASE WHEN COUNT(*) > 0 THEN '   !! A corriger' ELSE '' END
  FROM dba_users
 WHERE oracle_maintained = 'N'
   AND default_tablespace IN ('SYSTEM', 'SYSAUX')
UNION ALL
SELECT 'Espace occupe par les comptes applicatifs'
      ,TRIM(TO_CHAR(NVL(SUM(s.bytes), 0)/1073741824, '999,990.9')) || ' GB'
  FROM dba_segments s
  JOIN dba_users u ON u.username = s.owner
                  AND u.oracle_maintained = 'N'
UNION ALL
SELECT 'Session courante'
      ,USER || ' (schema ' || SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') || ')'
  FROM dual
;

PROMPT
PROMPT  Un compte = un schema. Les objets appartiennent au compte qui les a crees.
PROMPT  ILLIMITE* = privilege UNLIMITED TABLESPACE : le quota n'est pas applique.
PROMPT  Alerte espace illimite au-dela de 10 GB occupes, pas sur le seul privilege.
PROMPT
PROMPT  ORA-01536 quota atteint  |  ORA-01950 aucun quota  |  ORA-28002 mot de passe expirant
PROMPT
PROMPT ========================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_11
