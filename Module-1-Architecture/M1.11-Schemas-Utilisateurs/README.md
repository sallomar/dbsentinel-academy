# M1.11 - Schemas et Utilisateurs Oracle

> **DBSentinel Academy** - Formation Oracle gratuite en francais
> *Par Omar SALL - DBA Oracle 10+ ans production*

---

## Prerequis

- **Acces** : SYSDBA, SELECT ANY DICTIONARY ou SELECT_CATALOG_ROLE
- **Compatibilite** : Oracle 12c, 18c, 19c, 21c, 23ai
  (les colonnes `ORACLE_MAINTAINED` et `LAST_LOGIN` existent depuis 12c)

> **Nouveau sur Oracle ?** Consulte le [Guide Demarrage Complet](../../README.md#guide-demarrage-complet) dans le README principal.

---

## Les 4 scripts de ce module

### 1. check_schemas.sql (RECOMMANDE pour commencer)

**Objectif** : Panorama des comptes - qui existe, dans quel etat, avec quel quota

**Ce que tu vas voir :**
- Statut de chaque compte (OPEN, EXPIRED(GRACE), LOCKED), tablespace par defaut, profil
- Date de creation et derniere connexion (comptes dormants)
- Objets detenus, espace occupe, quota accorde et pourcentage consomme
- Synthese : comptes Oracle vs comptes applicatifs, comptes a corriger

**Execution :**
```sql
SQL> @check_schemas.sql
```

**Apercu du resultat :**
```
==================== COMPTES ET SCHEMAS - DIAGNOSTIC RAPIDE ====================

 Comptes applicatifs (comptes internes Oracle exclus)

Compte             Statut du compte   Tablespace defaut  Profil         Cree le     Dern. cnx   Alerte
------------------ ------------------ ------------------ -------------- ----------- ----------- ------------------------------
APP_PAIE           OPEN               APP_DATA           APP_PROFILE    12/03/2019  03/08/2026  OK
COMPTA             EXPIRED(GRACE)     APP_DATA           APP_PROFILE    05/09/2020  01/08/2026  !! Mot de passe en sursis
SUPPORT_N2         OPEN               SYSTEM             DEFAULT        15/02/2024  -           !! Objets crees dans SYSTEM

 Contenu et quota de chaque compte :

Compte              Objets  Tables Occupe       Quota              Verdict
------------------ ------- ------- ------------ ------------------ --------------------------------------
APP_PAIE               210      62       925 MB 2,048 MB (45.2%)   OK
BATCH_USER              61      19       124 MB ILLIMITE*          OK
COMPTA                 104      30       353 MB 400 MB (88.3%)     !! Quota presque atteint (ORA-01536)

 Synthese :

Information                                    Valeur
---------------------------------------------- --------------------------------
Comptes applicatifs                            7
Comptes Oracle internes (exclus de ce rapport) 35
Comptes ouverts                                5
Comptes verrouilles ou expires                 2
Comptes jamais connectes                       2
Comptes en espace illimite                     1
Comptes avec tablespace par defaut SYSTEM      1   !! A corriger
Espace occupe par les comptes applicatifs      1.9 GB
Session courante                               SYS (schema SYS)
```

---

### 2. v_objets_par_schema.sql

**Objectif** : Cartographier les objets et reperer ceux qui sont mal places

**Quand l'utiliser :**
- Avant une montee de version : detecter les objets metier crees dans SYS/SYSTEM
- Apres un deploiement : lister les objets INVALID a recompiler
- Pour tracer ce qui a change ces 30 derniers jours (jobs et partitions exclus :
  leur LAST_DDL_TIME bouge a chaque execution)
- Pour reperer les tables de controle DataPump laissees apres un import

> Chaque section affiche une ligne `Aucun ...` quand elle ne trouve rien : une section
> vide est un resultat, pas un doute sur l'execution du script.

**Execution :**
```sql
SQL> @v_objets_par_schema.sql
```

**Apercu du resultat :**
```
==================== CARTOGRAPHIE DES OBJETS PAR SCHEMA ====================

 Schemas applicatifs uniquement (schemas Oracle exclus)

Schema             Tables  Index  Vues   Seq PL/SQL  Trig   Syn Autres  Total INVALID
------------------ ------ ------ ----- ----- ------ ----- ----- ------ ------ -------
APP_PAIE               62     90    12     8     21     9     1      7    210       3
HR_ADMIN               34     51     9     4     12     6     0      5    121       1
COMPTA                 30     45     6     3      9     4     0      7    104       0
BATCH_USER             19     22     2     5      7     3     0      3     61       2
WEB_CONSULT             0      0     0     0      0     0     4      0      4       0

 Objets applicatifs mal places :

Schema             Objet                            Type             Localisation         Constat
------------------ -------------------------------- ---------------- -------------------- --------------------------------------
BATCH_USER         HISTO_IMPORT                     TABLE            Tablespace SYSTEM    !! Sature SYSTEM : risque ORA-01653
SYSTEM             CLIENTS_CRM                      TABLE            Schema SYSTEM        !! Perdu au prochain upgrade Oracle
SYSTEM             STATS_BATCH                      TABLE            Schema SYSTEM        !! Perdu au prochain upgrade Oracle
SYSTEM             SYS_IMPORT_SCHEMA_01             TABLE            Schema SYSTEM        Reste d'un DataPump : DROP possible
SYSTEM             TMP_IMPORT_PAIE                  TABLE            Schema SYSTEM        !! Perdu au prochain upgrade Oracle
```

> **Comment le script definit un objet applicatif** : par son **proprietaire**, pas par
> l'objet lui-meme. Le filtre porte sur `DBA_USERS.ORACLE_MAINTAINED = 'N'`.
> Ne jamais filtrer sur `DBA_OBJECTS.ORACLE_MAINTAINED` : Oracle cree lui-meme des
> milliers d'objets marques `'N'` (files DataPump, partitions AWR, objets Java,
> contextes). Sur une base 19c, `SYS` en compte plus de mille.

Pour la section **objets mal places**, deux regles supplementaires evitent de remonter
les objets techniques que SYS et SYSTEM contiennent legitimement :

| Regle | Ce qu'elle ecarte |
|-------|-------------------|
| Le nom doit etre un identifiant simple : `^[A-Z][A-Z0-9_]*$` | Tout ce qu'Oracle genere avec `$ # + = - /` : tables de stockage des nested tables (`SYSNTM$+#ZNX...`), files AQ (`AQ$_KUPC$...`), partitions AWR (`WRI$_...`) |
| Exclusion des familles Oracle a nom propre : `SYSNT`, `SYSTP`, `SYS_`, `QT<n>`, `KUPC`, `UTL_`, `DBMS_`, `LOGMNR`, `MVIEW`, `ODCI`, `SCHEDULER`... | `QT73057_BUFFER` (tampon de queue), `UTL_RECOMP_SEQ`, `SYSNTTV1UM75YWJF...` |

Les prefixes exigent une frontiere nette (`SYS_` avec underscore, `QT` suivi d'un chiffre),
pour ne pas ecarter des tables metier comme `SYSTEM_LOGS`, `DRH_AGENTS` ou `OLD_CLIENTS`.

---

### 3. v_privileges_audit.sql

**Objectif** : Revue de privileges prete a presenter (securite, audit, RGPD)

**Quand l'utiliser :**
- Revue annuelle des habilitations demandee par un auditeur
- Avant d'ouvrir un acces a un prestataire ou a un nouveau compte applicatif
- Apres un incident : qui pouvait reellement lire ou modifier cette table ?

> **Une ligne par beneficiaire, jamais une ligne par privilege.** Un compte a qui
> l'editeur a accorde 150 privileges systeme tient sur une ligne, avec le nombre de
> privileges critiques et le verdict. Idem pour les acces cross-schema : un schema
> qui accorde `SELECT` sur 3 000 tables a un role donne **une** ligne, pas 3 000.
> Les commandes de descente au detail sont rappelees en bas de sortie.

**Execution :**
```sql
SQL> @v_privileges_audit.sql
```

**Apercu du resultat :**
```
==================== AUDIT DES PRIVILEGES ET DES ROLES ====================

 Comptes et roles applicatifs (comptes internes Oracle exclus)

Beneficiaire         Type    Sensibles Critiques ADMIN  Principaux privileges                  Verdict
-------------------- ------- --------- --------- ------ -------------------------------------- ----------------------------------
BATCH_USER           USER          152        11 -      ALTER ANY TABLE, ALTER SYSTEM          !! Pouvoir equivalent DBA
APP_PAIE             USER            3         1 -      CREATE ANY TABLE, SELECT ANY SEQUENCE  !! Privileges critiques accordes
SUPPORT_N2           USER            1         1 -      ALTER SYSTEM                           !! Privileges critiques accordes
WEB_CONSULT          USER            1         1 -      SELECT ANY TABLE                       !! Privileges critiques accordes
ROLE_SUPPORT         ROLE            1         0 -      SELECT ANY DICTIONARY                  A revoir : portee hors du schema

 Droits accordes sur les objets d'un autre schema :

Schema source      Beneficiaire            Objets Droits accordes            Alerte
------------------ ---------------------- ------- -------------------------- ----------------------
APP_PAIE           PUBLIC                       1 SELECT                     !! Accorde a PUBLIC
HR_ADMIN           ROLE_LECTURE_WEB             3 SELECT                     OK
APP_PAIE           HR_ADMIN                     1 SELECT                     OK
COMPTA             APP_PAIE                     1 SELECT                     OK
COMPTA             ROLE_COMPTA_LECTURE          1 SELECT                     OK
HR_ADMIN           APP_PAIE                     1 2 droits (dont ecriture)   OK
HR_ADMIN           BATCH_USER                   1 4 droits (dont ecriture)   !! WITH GRANT OPTION

 Score de la revue de privileges :

Indicateur                                         Valeur     Verdict
-------------------------------------------------- ---------- ----------------------------------------------
Comptes avec un privilege ANY                           3     !! Revue necessaire : portee hors du schema
Comptes avec UNLIMITED TABLESPACE                       1     Les quotas sont ignores sur ces comptes
Role DBA accorde hors comptes Oracle                    1     !! CRITIQUE : pouvoir total accorde
Objets applicatifs accessibles a PUBLIC                 1     !! Lisible par tous les comptes de la base
Objets delegables (WITH GRANT OPTION)                   1     !! Le beneficiaire peut re-accorder le droit
Roles applicatifs definis (hors Oracle)                 3     Verifier le contenu de chaque role
Roles applicatifs jamais accordes                       0     OK : tous les roles sont accordes
```

---

### 4. v_synonymes_acces.sql

**Objectif** : Diagnostiquer ORA-00942 - la table existe, et pourtant l'appli ne la voit pas

**Quand l'utiliser :**
- Une application remonte `ORA-00942` alors que la table existe bien
- Apres une migration : verifier que les synonymes pointent toujours sur une cible valide
- Pour savoir combien de synonymes pointent sur chaque schema, et combien
  pointent dans le vide (synthese par schema cible)

**Execution :**
```sql
SQL> @v_synonymes_acces.sql
```

**Apercu du resultat :**
```
============== SYNONYMES ET ACCES CROSS-SCHEMA (DIAG ORA-00942) ==============

Contexte de la session                        Valeur
--------------------------------------------- ---------------------------------------------
Utilisateur connecte (USER)                   SYS
Schema courant (CURRENT_SCHEMA)               SYS
Container courant (CON_NAME)                  CDB$ROOT

 Synonymes publics sans aucun GRANT (cause numero 1 d'ORA-00942) :

Synonyme public              Schema cible       Objet cible                    Diagnostic
---------------------------- ------------------ ------------------------------ --------------------------------------------
BULLETIN_PAIE                APP_PAIE           BULLETIN_PAIE                  !! ORA-00942 pour tous sauf le proprietaire

 Synonymes orphelins : la cible n'existe plus (ORA-00980) :

Proprietaire     Synonyme                   Cible declaree (inexistante)             Action
---------------- -------------------------- ---------------------------------------- --------------------------------------------
APP_PAIE         ANCIEN_HISTO               APP_PAIE.BULLETIN_2019                   !! ORA-00980 : DROP SYNONYM ou recreer
PUBLIC           CLIENTS                    DEV_CRM.CLIENTS                          !! ORA-00980 : DROP SYNONYM ou recreer

 Synthese des synonymes par schema cible :

Schema cible         Synonymes Publics  Prives Orphelins Verdict
-------------------- --------- ------- ------- --------- ------------------------------------------
HR_ADMIN                     5       1       4         0 Synonymes publics : verifier les GRANT
APP_PAIE                     3       2       1         1 !! 1 synonyme(s) pointant dans le vide
COMPTA                       1       1       0         0 Synonymes publics : verifier les GRANT
```

---

## Le concept cle : USER et SCHEMA, une seule lettre de difference

| Notion | Ce que c'est | Ou on le voit |
|--------|--------------|---------------|
| **USER** | Le compte de connexion : login, mot de passe, profil, quota, tablespace par defaut | `DBA_USERS` |
| **SCHEMA** | La collection d'objets appartenant a ce compte, portant le meme nom | `DBA_OBJECTS.OWNER` |

**La relation est 1:1 et automatique.**
> `CREATE USER app_rh ...` cree un compte **et** un schema `APP_RH` vide.
> `DROP USER app_rh CASCADE` supprime le compte **et** tous ses objets.
> On ne peut pas avoir un schema sans compte, ni un compte sans schema.

**Consequence operationnelle** : sauvegarder, migrer ou auditer "une application"
revient a travailler sur **un schema**. C'est pour cela qu'un schema par application
n'est pas une coquetterie de puriste, mais la condition d'un export/import propre.

---

## SYS et SYSTEM : deux comptes, deux roles

| Compte | Ce qu'il possede | Usage legitime | A ne jamais faire |
|--------|------------------|----------------|-------------------|
| **SYS** | Le dictionnaire de donnees (`DBA_*`, `V$*`) | STARTUP, SHUTDOWN, RECOVER | Creer un objet applicatif, se connecter au quotidien |
| **SYSTEM** | Les outils d'administration Oracle | Taches admin courantes | Y deposer des tables metier ou temporaires |

Les deux ont `ORACLE_MAINTAINED = 'Y'` dans `DBA_USERS` : c'est le marqueur qui permet
de les exclure automatiquement des inventaires. Une seule section les regarde
volontairement, celle des **objets mal places** : c'est justement la qu'on cherche
ce qui n'aurait jamais du s'y trouver.

---

## Les 6 pieges classiques

| Erreur | Ce qui se passe reellement | Gravite | Action |
|--------|----------------------------|---------|--------|
| **Tables creees dans SYSTEM** | Un upgrade Oracle peut les supprimer ; SYSTEM sature | CRITIQUE | `@v_objets_par_schema.sql` puis migration vers un schema dedie |
| **DEFAULT TABLESPACE = SYSTEM** | Tout objet cree sans clause `TABLESPACE` atterrit dans SYSTEM | CRITIQUE | `ALTER USER x DEFAULT TABLESPACE app_data;` |
| **UNLIMITED TABLESPACE** | Le quota configure est ignore. Frequent (implicite via `RESOURCE` avant 12c), donc pas alarmant en soi : le script n'alerte qu'au-dela de 10 GB occupes, avec le verdict `!! 53.2 GB sans quota : a encadrer` | ELEVE si volumineux | `REVOKE UNLIMITED TABLESPACE` + `ALTER USER x QUOTA 5G ON app_data;` |
| **Aucun quota accorde** | `CREATE TABLE` echoue en ORA-01950, souvent decouvert en prod. Normal en revanche pour un compte de connexion sans objet : le script fait la difference | ELEVE si le compte a des objets | `ALTER USER x QUOTA 5G ON app_data;` |
| **Synonyme sans GRANT** | Le synonyme resout le nom mais ne donne aucun droit : ORA-00942 | CRITIQUE | `GRANT SELECT ON schema.objet TO compte;` **avant** le synonyme |
| **Grants directs au lieu de roles** | Revoquer oblige a passer sur chaque compte, un compte est toujours oublie | WARNING | Grants sur un role, role accorde aux comptes |

---

## FAQ du module

**Q: Quelle est la difference exacte entre un user et un schema ?**
> Le **user** est le compte de connexion (`DBA_USERS`), le **schema** est l'ensemble
> de ses objets (`DBA_OBJECTS.OWNER`). Ils portent le meme nom et sont crees ensemble.
> Un compte peut exister avec un schema vide (0 objet) : c'est le cas d'un compte
> de connexion applicatif. L'inverse est impossible.

**Q: Le compte est OPEN mais l'appli ne peut pas se connecter ?**
> `ACCOUNT_STATUS = OPEN` ne suffit pas. Il faut aussi le privilege `CREATE SESSION`
> (souvent via le role `CONNECT`). Sans lui : `ORA-01045: user lacks CREATE SESSION privilege`.
> `@v_privileges_audit.sql` section 2 montre les roles reellement accordes.

**Q: J'ai un ORA-00942 alors que la table existe, pourquoi ?**
> Trois causes possibles, dans cet ordre de frequence :
> 1. **Aucun GRANT** sur l'objet cible (le synonyme ne donne aucun droit)
> 2. Le **schema courant** de la session n'est pas celui de la table (`CURRENT_SCHEMA`)
> 3. La table existe dans un **autre schema** que celui suppose
> `@v_synonymes_acces.sql` traite les trois : contexte de session, synonymes sans grant,
> et la methode de diagnostic en 4 etapes en bas de sortie.

**Q: Un synonyme public suffit pour donner acces a une table ?**
> Non, et c'est l'erreur la plus courante. Un synonyme est **une traduction de nom**,
> pas un droit. `CREATE PUBLIC SYNONYM emp FOR hr.employes;` sans
> `GRANT SELECT ON hr.employes TO ...` donne un `ORA-00942` a tous les comptes
> sauf HR_ADMIN. C'est exactement la ligne `BULLETIN_PAIE` de l'exemple.

**Q: A quoi sert ORACLE_MAINTAINED, et pourquoi s'en mefier sur DBA_OBJECTS ?**
> Cette colonne (12c+) vaut `'Y'` pour ce qu'Oracle livre a la creation de la base.
> Sur `DBA_USERS` et `DBA_ROLES` elle est **fiable** : c'est le filtre de tous les
> scripts de ce module, bien plus sur qu'une liste de noms codee en dur.
> Sur `DBA_OBJECTS` elle est **trompeuse** : tout ce qu'Oracle cree *apres* la
> creation de la base vaut `'N'` (files DataPump, partitions AWR, objets Java,
> tables de stockage des nested tables). Sur une base 19c, `SYS` compte plus de mille
> objets marques `'N'` qui n'ont rien d'applicatif. Le script 2 ne l'utilise donc
> jamais seule : elle est combinee a des regles sur la forme du nom.

**Q: UNLIMITED TABLESPACE ou un quota explicite ?**
> Un quota explicite, toujours, en production. Avec `UNLIMITED TABLESPACE`, un batch
> qui boucle peut remplir tous les tablespaces et bloquer les autres applications.
> Le quota transforme un incident global (`ORA-01653` pour tout le monde) en incident
> local (`ORA-01536` pour le seul compte fautif).

**Q: Un objet INVALID, c'est grave ?**
> Non en soi : Oracle recompile automatiquement a la premiere utilisation. Le probleme
> est que cette recompilation peut **echouer** (dependance reellement cassee) et que
> l'erreur apparait alors au pire moment. Apres un deploiement, recompiler explicitement :
> `EXEC UTL_RECOMP.RECOMP_SERIAL('APP_PAIE');`

**Q: Comment savoir qui peut lire une table sensible ?**
> Trois chemins a verifier, tous couverts par `@v_privileges_audit.sql` :
> 1. Les grants directs sur l'objet (`DBA_TAB_PRIVS`, section 3)
> 2. Les grants portes par un **role** accorde a des comptes (sections 2 et 3)
> 3. Les privileges `SELECT ANY TABLE` qui court-circuitent tout (section 1)
> Oublier le troisieme chemin est l'erreur classique d'une revue d'habilitations.

---

## Vues Oracle utilisees

| Vue | Description |
|-----|-------------|
| `DBA_USERS` | Comptes : statut, tablespace defaut, profil, creation, LAST_LOGIN, ORACLE_MAINTAINED |
| `DBA_OBJECTS` | Tous les objets : OWNER (= schema), type, statut VALID/INVALID, LAST_DDL_TIME |
| `DBA_TABLES` | Tables par schema (utilise pour le comptage et la recherche par nom) |
| `DBA_SEGMENTS` | Espace reellement occupe par schema et tablespace de stockage |
| `DBA_TS_QUOTAS` | Quota accorde et consomme par compte et par tablespace (MAX_BYTES = -1 : illimite) |
| `DBA_SYS_PRIVS` | Privileges systeme accordes aux comptes et aux roles (ANY, ADMIN OPTION) |
| `DBA_ROLE_PRIVS` | Roles accordes aux comptes et aux autres roles (DEFAULT_ROLE) |
| `DBA_TAB_PRIVS` | Droits accordes sur les objets (SELECT, INSERT... et GRANTABLE) |
| `DBA_ROLES` | Liste des roles + ORACLE_MAINTAINED pour isoler les roles applicatifs |
| `DBA_SYNONYMS` | Synonymes publics et prives, schema et objet cible, DB_LINK |
| `SYS_CONTEXT` | Contexte de session : USER, CURRENT_SCHEMA, DB_NAME, CON_NAME |

---

## Pour aller plus loin

- **Theorie complete** : [Carrousel M1.11 sur LinkedIn](https://www.linkedin.com/posts/activity-7429423185395322880-Ippe)
- **Module precedent** : [M1.10 - UNDO Tablespace et Transactions](../M1.10-UNDO-Tablespace-Transactions/)
- **Voir aussi** : [M1.6 - Tablespaces et Datafiles](../M1.6-Tablespaces-Datafiles/) pour l'espace consomme par les segments
- **Prochain module** : M1.12 - Architecture Oracle, vue d'ensemble
- **Documentation Oracle** : [Managing Security for Oracle Database Users](https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/managing-security-for-oracle-database-users.html)

---

## A propos

**Auteur** : Omar SALL - DBA Oracle & Responsable Applications
**Experience** : 10+ ans en production critique (collectivites territoriales)
**Formation basee sur** : Formations ib Cegos (3000EUR+) + Livres Oracle 19c (ENI)

---

**#DBSentinelAcademy** | **#DBSA_M1_11** | Formation Oracle gratuite en francais
