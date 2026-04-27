# M1.7 - Online Redo Logs et Archivelog

> **DBSentinel Academy** - Formation Oracle gratuite en francais
> *Par Omar SALL - DBA Oracle 10+ ans production*

---

## Prerequis

- **Acces** : SYSDBA, SELECT ANY DICTIONARY ou SELECT_CATALOG_ROLE
- **Compatibilite** : Oracle 12c, 18c, 19c, 21c, 23ai

> **Nouveau sur Oracle ?** Consulte le [Guide Demarrage Complet](../../README.md#guide-demarrage-complet) dans le README principal.

---

## Les 4 scripts de ce module

### 1. check_redo_config.sql (RECOMMANDE pour commencer)

**Objectif** : Dashboard configuration redo : mode archive, FORCE LOGGING, multiplexage, sizing

**Ce que tu vas voir :**
- Configuration generale (mode archivage, FORCE LOGGING, nombre de groupes, taille)
- Statut de chaque groupe redo (CURRENT, INACTIVE, sequence)
- Verification securite avec alertes (5 points de controle)

**Execution :**
```sql
SQL> @check_redo_config.sql
```

**Apercu du resultat :**
```
==================== REDO LOGS - CONFIGURATION COMPLETE ====================

Configuration                            Valeur
---------------------------------------- ---------------------------------------------
Mode archivage                           ARCHIVELOG
Force Logging                            YES
Role base                                PRIMARY
Nombre de groupes redo                   4
Taille par groupe                        200 MB (uniforme)

 Verification securite :

Verification                             Resultat
---------------------------------------- ----------------------------------------
Mode archivage                           OK (ARCHIVELOG)
Force Logging                            OK (FORCE LOGGING actif)
Nombre de groupes                        OK (4 groupes)
Multiplexage (membres par groupe)        OK (min 2 membres)
Taille uniforme des groupes              OK (tous identiques)
```

---

### 2. v_log_switch_analysis.sql

**Objectif** : Analyse frequence log switches par heure sur 7 jours - "mes redo sont-ils trop petits ?"

**Quand l'utiliser :**
- Dimensionner correctement les redo logs
- Detecter les heures de pointe (trop de switches)
- Justifier un changement de taille aupres du management

**Execution :**
```sql
SQL> @v_log_switch_analysis.sql
```

**Apercu du resultat :**
```
==================== LOG SWITCHES - ANALYSE FREQUENCE ====================

Date         00h 01h 02h ... 08h 09h 10h 11h ... 17h 18h ... 23h Tot
------------ --- --- --- --- --- --- --- --- --- --- --- --- --- ---
24/03/2026     1   0   0       3   4   3   4       4   3       1  48
25/03/2026     1   0   1       4   3   4   3       3   3       0  49

 Recommandation dimensionnement :

Metrique                                       Valeur
--------------------------------------------- ------------------------------
Switches max par heure (7 derniers jours)      4 switches/h
Switches moyen par heure                       2.8 switches/h
Diagnostic                                     OK (objectif : 2-4 switches/h max)
```

---

### 3. v_fra_usage.sql

**Objectif** : Monitoring Fast Recovery Area - espace utilise, repartition, alertes saturation

**Quand l'utiliser :**
- Verifier que la FRA ne va pas saturer (risque ORA-19815 / ORA-00257)
- Voir la repartition par type de fichier (archives, backups, flashback)
- Identifier l'espace recuperable automatiquement

**Execution :**
```sql
SQL> @v_fra_usage.sql
```

**Apercu du resultat :**
```
==================== FRA - FAST RECOVERY AREA ====================

Configuration FRA                       Valeur
---------------------------------------- --------------------------------------------------
Emplacement FRA (DB_RECOVERY_FILE_DEST)  /u02/fra/ORCL
Taille FRA (DB_RECOVERY_FILE_DEST_SIZE)  50.0 GB

 Espace FRA :

Taille       Utilise      Libre        Recuperable  % Util  Statut
------------ ------------ ------------ ------------ ------- ---------------
    50.0 GB     32.5 GB     17.5 GB      8.2 GB    65.0%  OK

 Repartition espace FRA par type :

Type fichier                    % FRA   % Recup      Nb
------------------------------ ------- ---------- ----
ARCHIVED LOG                    45.2%     12.5%    892
BACKUP PIECE                    15.8%      3.7%     24
```

---

### 4. v_redo_multiplexing.sql

**Objectif** : Verification multiplexage - membres par groupe, disques utilises, alertes securite

**Quand l'utiliser :**
- Verifier que chaque groupe a au moins 2 membres sur des disques differents
- Detecter les membres en erreur (INVALID, STALE)
- Audit securite des redo logs

**Execution :**
```sql
SQL> @v_redo_multiplexing.sql
```

**Apercu du resultat :**
```
==================== REDO LOGS - MULTIPLEXAGE ET SECURITE ====================

 Grp Mbr Statut     Disques/Repertoires utilises                       Securite
---- --- ---------- -------------------------------------------------- --------------------
   1   2 INACTIVE   /u01/oradata/ORCL/ | /u02/oradata/ORCL/            OK (multiplex)
   2   2 INACTIVE   /u01/oradata/ORCL/ | /u02/oradata/ORCL/            OK (multiplex)
   3   2 CURRENT    /u01/oradata/ORCL/ | /u02/oradata/ORCL/            OK (multiplex)
   4   2 INACTIVE   /u01/oradata/ORCL/ | /u02/oradata/ORCL/            OK (multiplex)

 Verification globale :

Verification                                  Resultat
--------------------------------------------- ----------------------------------------
Groupes avec 1 seul membre                    OK : tous les groupes sont multiplexes
Membres avec statut INVALID ou STALE          OK : tous les membres sont valides
```

---

## Le concept cle : Online Redo Logs vs Archived Redo Logs

| Element | Online Redo Logs | Archived Redo Logs |
|---------|-----------------|-------------------|
| **Nature** | Journal circulaire actif | Copies historiques figees |
| **Processus** | LGWR ecrit en temps reel | ARCn copie les logs pleins |
| **Stockage** | Ecrasement circulaire (Grp1 > Grp2 > Grp3 > Grp1) | Permanent (jusqu'a suppression) |
| **Mode requis** | Toujours actif | ARCHIVELOG uniquement |
| **Recovery** | Crash recovery (instance) | Point-In-Time Recovery (PITR) |
| **Analogie** | Boite noire en boucle | Photos de la boite noire |

**La regle d'or :**
> NOARCHIVELOG en production = perte de donnees GARANTIE en cas de crash disque.
> Minimum 2 membres par groupe sur des disques DIFFERENTS. Un seul membre = risque fatal.

---

## Les 5 alertes critiques liees aux redo logs

| Alerte | Cause | Gravite | Action |
|--------|-------|---------|--------|
| **ORA-00257** | Destination archive pleine | CRITIQUE | Liberer espace FRA ou ajouter destination |
| **ORA-19815** | FRA pleine | CRITIQUE | RMAN DELETE OBSOLETE ou augmenter taille FRA |
| **checkpoint not complete** | Redo logs trop petits | WARNING | Augmenter taille des redo logs |
| **Membre INVALID/STALE** | Corruption membre redo | CRITIQUE | Recreer le membre immediatement |
| **> 6 switches/heure** | Redo sous-dimensionnes | WARNING | Augmenter taille (formule : Volume/h / nb_grp x 1.2) |

---

## FAQ du module

**Q: NOARCHIVELOG en production, c'est grave ?**
> Oui, c'est la pire configuration possible. En cas de crash disque,
> tu perds TOUTES les donnees depuis le dernier backup. Pas de PITR possible.
> `ALTER DATABASE ARCHIVELOG;` (necessite un restart en MOUNT).

**Q: Combien de groupes redo faut-il ?**
> Minimum 3 (Oracle le recommande). 4-5 pour les bases actives.
> Trop peu = contention LGWR. Trop = gaspillage espace.

**Q: Comment dimensionner les redo logs ?**
> Formule : Taille = (Volume_redo/h / nb_groupes) x 1.2
> Objectif : 2-4 log switches par heure max.
> Execute `v_log_switch_analysis.sql` pour mesurer.

**Q: C'est quoi la FRA (Fast Recovery Area) ?**
> Zone centralisee pour archives, backups, flashback logs.
> Configuree par DB_RECOVERY_FILE_DEST et DB_RECOVERY_FILE_DEST_SIZE.
> Oracle gere automatiquement la purge des fichiers obsoletes.

**Q: FORCE LOGGING, c'est quoi ?**
> Empeche les operations NOLOGGING (direct path load, CREATE TABLE AS SELECT NOLOGGING).
> Sans FORCE LOGGING, ces operations creent des "trous" dans les archives.
> Obligatoire si Data Guard ou si tu veux des archives completes.

---

## Vues Oracle utilisees

| Vue | Description |
|-----|-------------|
| `V$LOG` | Groupes redo log (statut, taille, sequence, membres) |
| `V$LOGFILE` | Membres physiques des redo logs (chemin, statut) |
| `V$LOG_HISTORY` | Historique des log switches (frequence, timing) |
| `V$DATABASE` | Mode archivage, FORCE LOGGING, database role |
| `V$PARAMETER` | Parametres FRA (db_recovery_file_dest, size) |
| `V$RECOVERY_FILE_DEST` | Espace FRA (taille, utilise, recuperable) |
| `V$RECOVERY_AREA_USAGE` | Repartition FRA par type de fichier |

---

## Pour aller plus loin

- **Theorie complete** : [Carrousel M1.7 sur LinkedIn](https://www.linkedin.com/posts/activity-7418913909467910144-a7Fw)
- **Module precedent** : [M1.6 - Tablespaces et Datafiles](../M1.6-Tablespaces-Datafiles/)
- **Prochain module** : M1.8 - Control Files
- **Documentation Oracle** : [Managing Redo Log Files](https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/managing-the-redo-log.html)

---

## A propos

**Auteur** : Omar SALL - DBA Oracle & Responsable Applications
**Experience** : 10+ ans en production critique (collectivites territoriales)
**Formation basee sur** : Formations ib Cegos (3000EUR+) + Livres Oracle 19c (ENI)

---

**#DBSentinelAcademy** | **#DBSA_M1_7** | Formation Oracle gratuite en francais
