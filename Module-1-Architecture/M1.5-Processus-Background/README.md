# M1.5 - Processus Background Oracle

> **DBSentinel Academy** - Formation Oracle gratuite en francais
> *Par Omar SALL - DBA Oracle 10+ ans production*

---

## Prerequis

- **Acces** : SYSDBA, SELECT ANY DICTIONARY ou SELECT_CATALOG_ROLE
- **Compatibilite** : Oracle 12c, 18c, 19c, 21c, 23ai

> **Nouveau sur Oracle ?** Consulte le [Guide Demarrage Complet](../../README.md#guide-demarrage-complet) dans le README principal.

---

## Les 4 scripts de ce module

### 1. check_bgprocess.sql (RECOMMANDE pour commencer)

**Objectif** : Dashboard rapide de tous les processus background + verification des 5 critiques

**Ce que tu vas voir :**
- Liste complete des processus background actifs avec PID et PGA
- Verification individuelle des 5 critiques (PMON, SMON, LGWR, DBW0, CKPT)
- Resume : nombre total, DBWn, ARCn, mode archivage

**Execution :**
```sql
SQL> @check_bgprocess.sql
```

**Apercu du resultat :**
```
==================== PROCESSUS BACKGROUND - DIAGNOSTIC RAPIDE ====================

Processus  Description                              PID OS   PGA (MB)
---------- ---------------------------------------- -------- ----------
ARC0       Archival Process 0                       14523       3.2 MB
CKPT       checkpoint                               14512       3.1 MB
DBW0       db writer process 0                      14510       8.5 MB
LGWR       Redo etc.                                14511      14.2 MB
PMON       process cleanup                          14501       2.1 MB
SMON       System Monitor Process                   14513       6.8 MB
...

 Processus critiques (si absent = PROBLEME) :

Critique Statut       Role
-------- ------------ ------------------------------------------------------------
PMON     ACTIF        Nettoyage sessions mortes. Si absent = instance crashee
SMON     ACTIF        Recovery crash + nettoyage segments. Si absent = instance instable
LGWR     ACTIF        Ecriture redo logs au COMMIT. Si absent = perte transactions
DBW0     ACTIF        Ecriture dirty buffers vers datafiles. Si bloque = free buffer waits
CKPT     ACTIF        Synchronisation checkpoint SGA/disque. Orchestre DBWn

 Resume processus :

Information                         Valeur
----------------------------------- --------------------
Processus background actifs         24
Dont DBWn (Database Writers)        1
Dont ARCn (Archivers)               3
Mode archivage                      ARCHIVELOG
```

---

### 2. v_bgprocess_detail.sql

**Objectif** : Analyse memoire PGA par processus background + localisation fichiers trace

**Quand l'utiliser :**
- Identifier quel processus consomme le plus de memoire
- Diagnostiquer un processus background anormalement gourmand
- Trouver les fichiers trace pour debug (tail -f)

**Execution :**
```sql
SQL> @v_bgprocess_detail.sql
```

**Apercu du resultat :**
```
==================== PROCESSUS BACKGROUND - ANALYSE DETAILLEE ====================

Process  Description                         PID OS   PGA Used   PGA Alloc  PGA Max
-------- ----------------------------------- -------- ---------- ---------- ----------
LGWR     Redo etc.                           14511      12.8 MB    14.2 MB    18.6 MB
DBW0     db writer process 0                 14510       7.1 MB     8.5 MB    12.3 MB
SMON     System Monitor Process              14513       5.4 MB     6.8 MB     9.2 MB
MMON     Manageability Monitor Process       14520       3.8 MB     4.5 MB     6.1 MB
...

 Top 5 processus background par PGA :

  # Process  PGA (MB)   % Total
--- -------- ---------- --------
  1 LGWR         14.2    20.3%
  2 DBW0          8.5    12.2%
  3 SMON          6.8     9.7%
  4 MMON          4.5     6.4%
  5 ARC0          3.2     4.6%

 Fichiers trace des processus critiques :

Process  Fichier Trace
-------- ----------------------------------------------------------------------------------
PMON     /u01/app/oracle/diag/rdbms/orcl/ORCL/trace/ORCL_pmon_14501.trc
SMON     /u01/app/oracle/diag/rdbms/orcl/ORCL/trace/ORCL_smon_14513.trc
LGWR     /u01/app/oracle/diag/rdbms/orcl/ORCL/trace/ORCL_lgwr_14511.trc
```

---

### 3. v_redo_checkpoint.sql

**Objectif** : Monitoring LGWR et CKPT - activite redo, log switches, waits, checkpoint

**Quand l'utiliser :**
- Diagnostiquer des lenteurs au COMMIT (log file sync)
- Verifier la frequence des log switches
- Analyser la sante du mecanisme de checkpoint
- Messages "checkpoint not complete" dans l'alert.log

**Execution :**
```sql
SQL> @v_redo_checkpoint.sql
```

**Apercu du resultat :**
```
==================== LGWR / CKPT - ACTIVITE REDO & CHECKPOINT ====================

 Grp  Seq#   Mo Statut     Arc Mbr
---- ------ --- ---------- --- ---
   1    856 200 INACTIVE   YES   2
   2    857 200 INACTIVE   YES   2
   3    858 200 CURRENT    NO    2
   4    855 200 INACTIVE   YES   2

 Attentes LGWR (log file sync = lenteur COMMIT) :

Evenement                           Total Waits     Temps (sec)     Moy (ms)
----------------------------------- --------------- --------------- ------------
log file parallel write                   145,678         312.4       2.14
log file sync                              89,456         245.8       2.75
log file switch completion                     45           1.2      26.67

 Statut checkpoint :

Element                                  Valeur
---------------------------------------- -------------------------
Checkpoint SCN (V$DATABASE)               12,345,678,901
Dernier checkpoint (min datafile)         30/03/2026 14:22:15
Log switches depuis startup              858
```

---

### 4. v_archive_monitor.sql

**Objectif** : Monitoring ARCn - mode archivage, destinations, historique, prevention ORA-00257

**Quand l'utiliser :**
- Verifier que l'archivage fonctionne correctement
- Surveiller l'espace des destinations d'archivage
- Analyser le rythme des log switches
- Prevenir ORA-00257 (destination archive pleine = base FREEZE)

**Execution :**
```sql
SQL> @v_archive_monitor.sql
```

**Apercu du resultat :**
```
==================== ARCn - MONITORING ARCHIVAGE ====================

Information                         Valeur
----------------------------------- ---------------------------------------------
Mode archivage (LOG_MODE)           ARCHIVELOG
Role base (DATABASE_ROLE)           PRIMARY
Processus ARCn actifs               3
Sequence redo courante              858

 Destinations d'archivage :

Destination               Statut     Chemin
------------------------- ---------- -------------------------------------------------------
LOG_ARCHIVE_DEST_1        VALID      /u02/archive/ORCL/

 Rythme d'archivage (log switches) :

Periode                   Switches   Moy (min)
------------------------- ---------- ---------------
Derniere heure                   3         20.0
Dernieres 24 heures             82         17.6
```

---

## Le concept cle : 5 processus critiques + 1 optionnel

| Processus | Nom complet | Role | Si meurt / bloque |
|-----------|-------------|------|-------------------|
| **PMON** | Process Monitor | Nettoyage sessions mortes, liberation verrous | Instance **CRASH** |
| **SMON** | System Monitor | Recovery crash, nettoyage segments temporaires | Instance **CRASH** |
| **LGWR** | Log Writer | Ecriture redo au COMMIT (synchrone, garantit ACID) | Instance **CRASH** + transactions perdues |
| **DBWn** | Database Writer | Ecriture dirty buffers vers datafiles (asynchrone) | free buffer waits, sessions **bloquees** |
| **CKPT** | Checkpoint | Signale DBWn, met a jour SCN checkpoint | Instance **CRASH** |
| **ARCn** | Archiver *(optionnel)* | Copie redo logs vers archive (ARCHIVELOG uniquement) | ORA-00257, base **FREEZE** |

**La regle d'or :**
> PMON, SMON, LGWR = processus critiques. Un seul qui meurt = Instance CRASH immediat.
> LGWR ecrit au COMMIT (synchrone). DBWn ecrit en arriere-plan (asynchrone). Ne pas confondre !

---

## Les 6 erreurs critiques liees aux processus

| Erreur | Cause | Gravite | Action |
|--------|-------|---------|--------|
| **ORA-00600** | Erreur interne (PMON/SMON crash) | CRITIQUE | Redemarrer instance + alert.log |
| **ORA-00471** | LGWR failure | CRITIQUE | Verifier I/O disque + redo logs |
| **ORA-00257** | Destination archive pleine | BLOQUANT | Liberer espace URGENT |
| **ORA-27101** | Instance won't start | CRITIQUE | Verifier alert.log ligne par ligne |
| **checkpoint not complete** | Redo logs trop petits ou trop peu | WARNING | Augmenter taille/nombre redo logs |
| **free buffer waits** | DBWn ne suit pas la charge | WARNING | Verifier I/O disque, ajouter DBWn |

---

## FAQ du module

**Q: L'instance a crashe, que verifier en premier ?**
> 1. `tail -50 $ORACLE_BASE/diag/.../alert_SID.log` → Chercher ORA-00600, ORA-00471, "died", "terminated"
> 2. `ps -ef | grep pmon` → PMON absent = instance morte
> 3. `sqlplus / as sysdba` puis `STARTUP;` → Observer les messages

**Q: C'est quoi la difference entre LGWR et DBWn ?**
> LGWR ecrit les redo logs **au COMMIT** (synchrone, garantit durabilite).
> DBWn ecrit les blocs de donnees **en arriere-plan** (asynchrone, pas au COMMIT).
> Confusion frequente : COMMIT != ecriture datafiles.

**Q: Combien de DBWn est normal ?**
> 1 seul (DBW0) suffit pour la plupart des bases. Ajouter DBW1...DBW9
> uniquement si `free buffer waits > 0` dans V$SYSTEM_EVENT.
> Ne JAMAIS ajouter sans analyser la cause racine.

**Q: LOG_CHECKPOINT_TIMEOUT = quelle valeur ?**
> Recommandation : 180-300 secondes (3-5 min). Trop frequent (< 60s) = I/O satures.
> Trop rare (> 600s) = recovery long apres crash.

**Q: ORA-00257 en production, que faire en urgence ?**
> 1. `ARCHIVE LOG LIST;` → Verifier la destination
> 2. `df -h /chemin/archive` → Verifier l'espace disque
> 3. Liberer de l'espace ou `RMAN> BACKUP ARCHIVELOG ALL DELETE INPUT;`
> 4. L'archivage reprend automatiquement

---

## Vues Oracle utilisees

| Vue | Description |
|-----|-------------|
| `V$BGPROCESS` | Processus background (nom, description, adresse) |
| `V$PROCESS` | Processus avec PGA, PID OS, fichier trace |
| `V$LOG` | Groupes redo log (statut, taille, sequence) |
| `V$LOG_HISTORY` | Historique des log switches |
| `V$SYSSTAT` | Statistiques systeme (redo size, redo writes) |
| `V$SYSTEM_EVENT` | Evenements d'attente (log file sync, free buffer waits) |
| `V$DATABASE` | Infos base (log_mode, checkpoint_change#, database_role) |
| `V$DATAFILE_HEADER` | En-tete datafiles (checkpoint_time) |
| `V$ARCHIVE_DEST` | Destinations d'archivage (statut, chemin, erreurs) |
| `V$ARCHIVED_LOG` | Historique des archive logs generes |
| `V$INSTANCE` | Statut instance (startup_time) |

---

## Pour aller plus loin

- **Theorie complete** : [Carrousel M1.5 sur LinkedIn](https://www.linkedin.com/posts/activity-7413840464006520832-Z555)
- **Module precedent** : [M1.4 - Memoire Oracle : SGA et PGA](../M1.4-Memoire-SGA-PGA/)
- **Prochain module** : M1.6 - Tablespaces et Datafiles
- **Documentation Oracle** : [Background Processes](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/process-architecture.html)

---

## A propos

**Auteur** : Omar SALL - DBA Oracle & Responsable Applications
**Experience** : 10+ ans en production critique (collectivites territoriales)
**Formation basee sur** : Formations ib Cegos (3000EUR+) + Livres Oracle 19c (ENI)

---

**#DBSentinelAcademy** | **#DBSA_M1_5** | Formation Oracle gratuite en francais
