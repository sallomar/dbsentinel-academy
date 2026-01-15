# DBSentinel Academy - Scripts SQL Oracle

> **Formation Oracle gratuite en francais**
> Scripts production-ready commentes et testes

---

## A propos

**DBSentinel Academy** est une initiative de formation Oracle gratuite creee par **Omar SALL**, DBA Oracle avec 10+ ans d'experience en production critique.

Cette formation est basee sur :
- Formations professionnelles ib Cegos (valeur 3000EUR+)
- Livres de reference Oracle 19c (Editions ENI)
- Experience terrain de DBA

---

## Modules disponibles

> Les carrousels theoriques sont publies sur mon profil [LinkedIn](https://www.linkedin.com/in/omar-sall/)

### Module 1 : Architecture Oracle

| Module | Titre | Scripts | Theorie |
|--------|-------|:-------:|:-------:|
| [M1.1](Module-1-Architecture/M1.1-Instance-vs-Database/) | Instance vs Database | 3 | [Carrousel](https://www.linkedin.com/posts/activity-7404830055090032641-W67c) |
| M1.2 | Les 5 Types de Fichiers | - | [Carrousel](https://www.linkedin.com/posts/activity-7406230295471013888-Weae) |
| M1.3 | Alert.log | - | [Carrousel](https://www.linkedin.com/posts/activity-7408767001642287104-lwKf) |
| M1.4 | Memoire Oracle (SGA/PGA) | - | [Carrousel](https://www.linkedin.com/posts/activity-7411303730580602880-i2D_) |
| M1.5 | Processus Background | - | [Carrousel](https://www.linkedin.com/posts/activity-7413840464006520832-Z555) |
| M1.6 | Tablespaces et Datafiles | - | [Carrousel](https://www.linkedin.com/posts/activity-7416377171096670208-K9Ug) |

> **Prochain module** : M1.7 - Online Redo Logs (Lundi)

---

## Caracteristiques des scripts

Tous les scripts de ce depot sont :

- **Production-ready** : Requetes SELECT securisees, sans risque
- **Commentes en francais** : Explications claires et pedagogiques
- **Compatibles** : Oracle 12c, 18c, 19c, 21c, 23ai
- **Formattes** : Sortie lisible avec COL FORMAT
- **Sans dependances** : Executables directement dans SQL*Plus ou SQL Developer
- **Securises** : Requetes SELECT uniquement, aucune modification
- **Documentes** : Chaque module a un README detaille

---

## Tu es debutant ? Commence ici !

Ce guide t'accompagne **du telechargement a l'execution**. Meme si c'est ta premiere fois sur Oracle, tu vas y arriver.

---

## Guide Demarrage Complet

### Etape 1 : Telecharger les scripts

**Option A - Telecharger tout le depot (recommande)**

Va sur GitHub et clique "Download ZIP" :
```
https://github.com/sallomar/dbsentinel-academy
```

**Option B - Telecharger un script individuel**

Clique sur le fichier, puis "Raw", puis "Enregistrer sous".

---

### Etape 2 : Deposer les scripts sur ton serveur Oracle

**Sur LINUX :**
```bash
# Creer un dossier pour les scripts
mkdir -p /home/oracle/scripts

# Copier les fichiers telecharges (depuis ton PC vers le serveur)
# Si tu as telecharge sur ton PC, utilise scp :
scp *.sql oracle@serveur:/home/oracle/scripts/

# OU si tu es deja sur le serveur, copie depuis /tmp ou autre
cp /tmp/*.sql /home/oracle/scripts/

# Verifier que les fichiers sont la
ls -la /home/oracle/scripts/
```

**Sur WINDOWS :**
```
1. Creer le dossier : C:\oracle\scripts\
   - Ouvre l'Explorateur de fichiers
   - Va dans C:\oracle\ (cree-le s'il n'existe pas)
   - Clic droit > Nouveau > Dossier > nomme-le "scripts"

2. Copier les fichiers .sql telecharges dans ce dossier

3. Verifier qu'ils sont bien la
```

---

### Etape 3 : Configurer l'environnement Oracle

#### Sur LINUX :

**METHODE RAPIDE (si Oracle est deja installe correctement) :**
```bash
# Le fichier .bash_profile contient souvent les variables Oracle
source /home/oracle/.bash_profile

# Verifier que ca a marche
echo $ORACLE_SID
# Doit afficher le nom de ta base (ex: ORCL, PROD, TEST...)
```

**Si ca n'affiche rien, tu dois configurer manuellement.**

---

**Comprendre les variables Oracle :**

```
ORACLE_HOME = Le dossier ou Oracle est installe
              Exemple : /u01/app/oracle/product/19.0.0/dbhome_1
                        │              │       │     │
                        │              │       │     └── dbhome_1 = nom du "home" Oracle
                        │              │       │
                        │              │       └── 19.0.0 = VERSION d'Oracle
                        │              │           (12.2.0, 18.0.0, 19.0.0, 21.0.0...)
                        │              │
                        │              └── oracle/product = dossier standard
                        │
                        └── /u01/app = racine d'installation standard Linux
                            (peut aussi etre /opt/oracle ou autre)

ORACLE_SID  = Le NOM de ta base de donnees
              Exemples : ORCL, PROD, DEV, TEST, CDB1...
```

**Comment trouver TES valeurs ?**
```bash
# Trouver le chemin ORACLE_HOME
ls -d /u01/app/oracle/product/*/dbhome_*
ls -d /opt/oracle/product/*/dbhome_*

# Trouver le nom de ta base (ORACLE_SID)
cat /etc/oratab
# Format : NOM_BASE:/chemin/oracle_home:Y ou N
# Exemple : ORCL:/u01/app/oracle/product/19.0.0/dbhome_1:Y
```

---

**Configuration manuelle (ADAPTE a tes valeurs) :**
```bash
# ADAPTE CES VALEURS A TON INSTALLATION !
# - Remplace 19.0.0 par TA version Oracle
# - Remplace ORCL par LE NOM de ta base

export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=ORCL
export PATH=$ORACLE_HOME/bin:$PATH
```

**Exemples selon ta version Oracle :**
```bash
# Oracle 19c :
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1

# Oracle 21c :
export ORACLE_HOME=/u01/app/oracle/product/21.0.0/dbhome_1

# Oracle 12c :
export ORACLE_HOME=/u01/app/oracle/product/12.2.0/dbhome_1

# Oracle XE (Express Edition) :
export ORACLE_HOME=/opt/oracle/product/21c/dbhomeXE
```

**Pour rendre la configuration PERMANENTE**, ajoute ces lignes dans `~/.bash_profile` :
```bash
# Editer le fichier
vi ~/.bash_profile

# Ajouter ces lignes (avec TES valeurs)
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=ORCL
export PATH=$ORACLE_HOME/bin:$PATH

# Sauvegarder et quitter vi : Echap puis :wq

# Recharger le profil
source ~/.bash_profile
```

---

#### Sur WINDOWS :

**Etape 3a : Verifier si deja configure**

Ouvre une invite de commandes (cmd) et tape :
```cmd
echo %ORACLE_SID%
```

**Si ca affiche le nom de ta base (ex: ORCL)** : C'est bon, passe a l'etape 4.

**Si ca affiche juste `%ORACLE_SID%` ou une ligne vide** : Tu dois configurer les variables.

---

**Comprendre les variables Oracle :**

```
ORACLE_HOME = Le dossier ou Oracle est installe
              Exemple : C:\app\oracle\product\19.0.0\dbhome_1

ORACLE_SID  = Le NOM de ta base de donnees (identifiant unique)
              Exemples courants : ORCL, PROD, DEV, TEST, CDB1...
```

**Comment connaitre TES valeurs ?**

| Variable | Comment la trouver |
|----------|-------------------|
| ORACLE_SID | Demande a ton DBA, ou regarde le nom du service Oracle dans les Services Windows |
| Version Oracle | Regarde les dossiers dans `C:\app\oracle\product\` - tu verras `19.0.0` ou `21.0.0` etc. |
| ORACLE_HOME | C'est le chemin complet : `C:\app\oracle\product\<VERSION>\dbhome_1` |

---

**METHODE 1 : Configuration TEMPORAIRE (rapide, pour tester)**

Dans l'invite de commandes, tape (en ADAPTANT a tes valeurs) :
```cmd
REM ADAPTE CES VALEURS A TON INSTALLATION !
set ORACLE_HOME=C:\app\oracle\product\19.0.0\dbhome_1
set ORACLE_SID=ORCL
set PATH=%ORACLE_HOME%\bin;%PATH%
```

---

**METHODE 2 : Configuration PERMANENTE (recommande)**

1. **Ouvrir les Variables d'environnement**
   - Tape "variables" dans la recherche Windows
   - Clique sur "Modifier les variables d'environnement systeme"
   - Clique sur le bouton "Variables d'environnement..."

2. **Ajouter ORACLE_HOME** (dans "Variables systeme")
   - Clique sur "Nouvelle..."
   - Nom de la variable : `ORACLE_HOME`
   - Valeur : Le chemin vers TON installation Oracle
   - Clique OK

3. **Ajouter ORACLE_SID** (dans "Variables systeme")
   - Clique sur "Nouvelle..."
   - Nom de la variable : `ORACLE_SID`
   - Valeur : Le NOM de ta base de donnees
   - Clique OK

4. **Modifier PATH** (dans "Variables systeme")
   - Selectionne "Path" et clique "Modifier..."
   - Clique "Nouveau"
   - Ajoute : `%ORACLE_HOME%\bin`
   - Clique OK

5. **Fermer et rouvrir cmd**
   - Verifie : `echo %ORACLE_SID%` doit afficher le nom de ta base

---

**Comment trouver le bon chemin ORACLE_HOME ?**

Si tu ne connais pas le chemin exact :
```cmd
REM Chercher ou Oracle est installe
dir /s /b C:\oracle.exe 2>nul
dir /s /b C:\app\oracle\product\*\dbhome_1 2>nul

REM Ou regarde dans le registre Windows
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\ORACLE" /s | findstr ORACLE_HOME
```

---

### Etape 4 : Se connecter a Oracle avec SQL*Plus

#### PRIVILEGES REQUIS

Les scripts de ce depot interrogent des vues systeme (V$INSTANCE, V$DATABASE, V$SGA...).

**Tu dois avoir UN de ces privileges :**

| Privilege | Qui l'a ? | Comment verifier |
|-----------|-----------|------------------|
| SYSDBA | DBA systeme, compte oracle/sys | Tu peux faire `sqlplus / as sysdba` |
| SELECT ANY DICTIONARY | DBA applicatif | `SELECT * FROM session_privs WHERE privilege LIKE '%DICTIONARY%';` |
| SELECT_CATALOG_ROLE | Utilisateur avec ce role | `SELECT * FROM session_roles WHERE role = 'SELECT_CATALOG_ROLE';` |

---

#### METHODE 1 : Connexion locale SYSDBA (DBA sur le serveur)

C'est la methode la plus simple si tu es SUR le serveur Oracle :

```bash
sqlplus / as sysdba
```

**Explication :**
- `/` = utilise l'authentification OS (pas besoin de mot de passe)
- `as sysdba` = connexion avec privilege SYSDBA

---

#### METHODE 2 : Connexion avec sqlplus /nolog (plus securise)

Cette methode evite d'afficher le mot de passe dans l'historique :

```bash
sqlplus /nolog
```

Puis une fois dans SQL*Plus :
```sql
SQL> CONNECT / AS SYSDBA
Connected.

-- OU avec un compte specifique :
SQL> CONNECT sys/mon_mot_de_passe AS SYSDBA
Connected.

-- OU compte applicatif avec privileges :
SQL> CONNECT scott/tiger
Connected.
```

---

#### METHODE 3 : Connexion a distance via TNS (depuis un poste client)

Si tu n'es PAS sur le serveur Oracle mais sur ton PC :

**Option A - Avec alias TNS :**
```bash
sqlplus sys/mot_de_passe@ORCL as sysdba
```

**Option B - Easy Connect (sans tnsnames.ora) :**
```bash
sqlplus sys/mot_de_passe@//serveur:1521/ORCL as sysdba
```

Format Easy Connect :
```
//hostname:port/service_name
   │        │    │
   │        │    └── Nom du service (souvent = ORACLE_SID)
   │        └── Port listener (defaut: 1521)
   └── Nom ou IP du serveur Oracle
```

**Exemples concrets :**
```bash
# Serveur local, port standard
sqlplus scott/tiger@//localhost:1521/ORCL

# Serveur distant
sqlplus sys/password@//192.168.1.100:1521/PROD as sysdba

# Avec nom DNS
sqlplus sys/password@//srv-oracle.monentreprise.com:1521/PROD as sysdba
```

---

#### METHODE 4 : Compte applicatif (developpeur, analyste)

Si tu n'as pas SYSDBA mais que ton DBA t'a donne les privileges necessaires :

```bash
sqlplus mon_user/mon_password@MA_BASE
```

**Note :** Les scripts fonctionneront si ton DBA t'a accorde :
- `GRANT SELECT ANY DICTIONARY TO mon_user;`
- OU `GRANT SELECT_CATALOG_ROLE TO mon_user;`

---

#### Verification de connexion reussie

**Tu dois voir :**
```
SQL*Plus: Release 19.0.0.0.0 - Production on Tue Jan 14 10:30:00 2026

Copyright (c) 1982, 2019, Oracle.  All rights reserved.

Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.3.0.0.0

SQL>
```

Le `SQL>` signifie que tu es connecte et pret a executer des commandes.

---

#### Tableau des erreurs de connexion

| Erreur | Cause | Solution |
|--------|-------|----------|
| `ORA-01034: ORACLE not available` | L'instance Oracle n'est pas demarree | Tape `STARTUP` dans SQL*Plus (si SYSDBA), sinon contacte ton DBA |
| `ORA-12162: TNS:net service name is incorrectly specified` | ORACLE_SID n'est pas configure | Configure ORACLE_SID (voir etape 3) |
| `'sqlplus' n'est pas reconnu...` | PATH n'inclut pas le dossier bin d'Oracle | Configure PATH (voir etape 3) |
| `ORA-01031: insufficient privileges` | Tu n'as pas les droits SYSDBA | Utilise une autre methode de connexion, ou demande les privileges a ton DBA |
| `ORA-12541: TNS:no listener` | Le listener Oracle n'est pas demarre | Sur le serveur : `lsnrctl start` |
| `ORA-12514: TNS:listener does not currently know of service` | Mauvais nom de service | Verifie le nom du service dans tnsnames.ora ou utilise `lsnrctl status` |
| `ORA-00942: table or view does not exist` | Pas de privilege sur les vues V$ | Demande `SELECT ANY DICTIONARY` a ton DBA |
| `ORA-01017: invalid username/password` | Mauvais identifiants | Verifie username et password (attention aux majuscules depuis 11g) |

---

#### Note CDB/PDB (Oracle 12c et versions superieures)

Depuis Oracle 12c, il existe l'architecture **Container Database (CDB)** avec des **Pluggable Databases (PDB)**.

**Verifier ou tu es connecte :**
```sql
SQL> SHOW CON_NAME

CON_NAME
------------------------------
CDB$ROOT
```

| Valeur | Signification |
|--------|---------------|
| `CDB$ROOT` | Tu es au niveau CDB (container racine) |
| `PDB$SEED` | Template PDB (ne pas modifier) |
| `NOM_PDB` | Tu es dans une PDB specifique |

**Si tu veux executer un script dans une PDB specifique :**
```sql
SQL> ALTER SESSION SET CONTAINER = MAPDB;
Session altered.

SQL> @nom_script.sql
```

---

### Etape 5 : Executer un script

**Tu as 2 options pour executer un script :**

---

**OPTION A : Donner le chemin complet (recommande pour debuter)**

Tu peux executer le script depuis n'importe quel repertoire en donnant le chemin complet :

**Sur LINUX :**
```sql
SQL> @/home/oracle/scripts/nom_script.sql
```

**Sur WINDOWS :**
```sql
SQL> @C:\oracle\scripts\nom_script.sql
```

---

**OPTION B : Se placer dans le dossier du script d'abord**

Avant de lancer sqlplus, place-toi dans le bon dossier :

**Sur LINUX :**
```bash
cd /home/oracle/scripts
sqlplus / as sysdba
SQL> @nom_script.sql
```

**Sur WINDOWS :**
```cmd
cd C:\oracle\scripts
sqlplus / as sysdba
SQL> @nom_script.sql
```

---

**Erreurs possibles a l'execution :**

| Erreur | Cause | Solution |
|--------|-------|----------|
| `SP2-0310: unable to open file` | Le chemin est incorrect ou le fichier n'existe pas | Verifie que le fichier est bien a l'endroit indique |
| `SP2-0310` avec chemin correct | Probleme d'encodage du chemin | Utilise des / au lieu de \ : `@C:/oracle/scripts/script.sql` |

---

### Etape 6 : Lire le resultat

**C'est tout !** Le script s'execute et t'affiche les resultats.

Chaque script contient des `PROMPT` qui t'expliquent ce que tu vois.

---

## Exemple de sortie (M1.1)

```
================== INSTANCE (TEMPORAIRE) ==================

Instance     Statut   Demarrage            Serveur
------------ -------- -------------------- --------------------
ORCL         OPEN     14/01/2026 08:15:32  srv-oracle-prod

 Memoire Instance (SGA + PGA) :

Composant                  Mo
-------------------- --------
SGA (partagee)          2,048
PGA (privee)              256
--- TOTAL MEMOIRE ---   2,304

 Processus background actifs :

Nb Processus
-----------------
42 processus actifs

================== DATABASE (PERMANENT) ==================

Base         Mode         Archivage    Role
------------ ------------ ------------ ----------
ORCL         READ WRITE   ARCHIVELOG   PRIMARY

 Fichiers sur disque :

Type Fichier      Nb
--------------- ----
DATAFILES          5
REDO LOGS          3
CONTROL FILES      2
TEMP FILES         1

====================== RESUME M1.1 ======================

 INSTANCE = Memoire (SGA+PGA) + Processus --> TEMPORAIRE
            Disparait au SHUTDOWN

 DATABASE = Fichiers sur disque           --> PERMANENT
            Reste intact au SHUTDOWN

 REGLE D'OR : SHUTDOWN = couper le moteur, pas detruire la voiture

==========================================================
```

---

## Questions frequentes (generales)

### Questions sur la connexion

**Q: Le script affiche ORA-01034, que faire ?**
> L'instance n'est pas demarree. Tape `STARTUP` puis reessaie (si tu as SYSDBA).

**Q: Je n'ai pas SYSDBA, je peux quand meme utiliser les scripts ?**
> Oui ! Demande a ton DBA de t'accorder :
> `GRANT SELECT ANY DICTIONARY TO ton_user;`
> Puis connecte-toi avec ton compte : `sqlplus ton_user/password@BASE`

**Q: Quelle est la difference entre `sqlplus / as sysdba` et `sqlplus /nolog` ?**
> - `sqlplus / as sysdba` : Connexion directe avec authentification OS
> - `sqlplus /nolog` : Ouvre SQL*Plus sans connexion, tu dois faire `CONNECT` ensuite
> La 2eme methode est plus securisee car le mot de passe n'apparait pas dans l'historique.

**Q: Comment me connecter a distance depuis mon PC ?**
> Utilise Easy Connect : `sqlplus user/pass@//serveur:1521/SERVICE`
> Ou configure tnsnames.ora et utilise l'alias : `sqlplus user/pass@ALIAS`

**Q: ORA-00942: table or view does not exist ?**
> Tu n'as pas les privileges sur les vues V$. Demande a ton DBA :
> `GRANT SELECT ANY DICTIONARY TO ton_user;`

### Questions sur la configuration

**Q: La commande `set` sur Windows ne marche pas au redemarrage ?**
> Normal ! `set` est temporaire. Pour une config permanente, utilise les
> Variables d'environnement Windows (voir Etape 3, Methode 2).

**Q: Je ne trouve pas le chemin ORACLE_HOME ?**
> Voir la section "Comment trouver le bon chemin ORACLE_HOME" dans l'Etape 3.

**Q: C'est quoi CDB$ROOT vs ma PDB ?**
> Depuis Oracle 12c, une instance peut heberger plusieurs bases (PDB).
> CDB$ROOT est le conteneur racine. Utilise `SHOW CON_NAME` pour voir ou tu es.
> Pour changer : `ALTER SESSION SET CONTAINER = NOM_PDB;`

---

## Calendrier de publication

| Jour | Contenu | Plateforme |
|------|---------|------------|
| **Lundi** | Carrousel theorique | LinkedIn |
| **Jeudi** | Scripts SQL (annonce) OU Infographie rappel | GitHub + LinkedIn |

---

## Auteur

**Omar SALL**
- DBA Oracle & Responsable Applications
- 10+ ans d'experience production
- Collectivites territoriales francaises

**LinkedIn** : [Omar SALL](https://www.linkedin.com/in/omar-sall/)

---

## Licence

Ces scripts sont fournis gratuitement dans un but educatif.
Utilisez-les librement, modifiez-les selon vos besoins.
Attribution appreciee : **#DBSentinelAcademy**

---

## Contribuer

Vous avez trouve un bug ? Une amelioration a proposer ?
Ouvrez une issue ou soumettez une pull request.

---

**#DBSentinelAcademy** | Formation Oracle gratuite en francais
