# M1.8 - Control Files

> **DBSentinel Academy** - Formation Oracle gratuite en francais
> *Par Omar SALL - DBA Oracle 10+ ans production*

---

## Prerequis

- **Acces** : SYSDBA, SELECT ANY DICTIONARY ou SELECT_CATALOG_ROLE
- **Compatibilite** : Oracle 12c, 18c, 19c, 21c, 23ai

> **Nouveau sur Oracle ?** Consulte le [Guide Demarrage Complet](../../README.md#guide-demarrage-complet) dans le README principal.

---

## Les 4 scripts de ce module

### 1. check_controlfile.sql (RECOMMANDE pour commencer)

**Objectif** : Dashboard CF avec verification multiplexage 3 copies + DBID + securite

**Ce que tu vas voir :**
- Liste des control files avec taille et statut
- Identite de la base (DBID, nom, date creation, checkpoint SCN)
- 4 verifications securite (multiplexage, statut, placement disques, type CF)

**Execution :**
```sql
SQL> @check_controlfile.sql
```

**Apercu du resultat :**
```
==================== CONTROL FILES - DIAGNOSTIC RAPIDE ====================

   # Control File                                  Taille     Statut
---- --------------------------------------------- ---------- ----------
   1 /u01/oradata/ORCL/control01.ctl                18.5 MB   OK
   2 /u02/oradata/ORCL/control02.ctl                18.5 MB   OK
   3 /u03/oradata/ORCL/control03.ctl                18.5 MB   OK

 Identite de la base :

Information                              Valeur
---------------------------------------- --------------------------------------------------
DBID (identifiant unique base)           1547283649
Nom de la base                           ORCL
Type Control File                        CURRENT
Checkpoint SCN courant                   12,847,569,234

 Verification securite :

Verification                             Resultat
---------------------------------------- -------------------------------------------------------
Nombre de copies multiplexees            OK (3 copies)
Statut des control files                 OK : tous les CF sont valides
Disques utilises (placement)             OK : CF sur 3 disques differents
Type Control File                        OK (CURRENT = production normale)
```

---

### 2. v_cf_record_sections.sql

**Objectif** : Monitoring sections internes - circulaires (ARCHIVED_LOG, BACKUP) vs permanentes

**Quand l'utiliser :**
- Prevenir saturation sections circulaires (ARCHIVED_LOG, BACKUP_PIECE)
- Verifier le parametre CONTROL_FILE_RECORD_KEEP_TIME
- Anticiper ORA-00245 (CF trop petit pour autobackup)

**Execution :**
```sql
SQL> @v_cf_record_sections.sql
```

**Apercu du resultat :**
```
==================== CF RECORD SECTIONS - UTILISATION INTERNE ====================

Section                         Total Utilises  % Util  Nature          Statut
---------------------------- -------- -------- ------- --------------- ---------------
DATABASE                            1        1  100.0%  Permanente      OK
LOG HISTORY                     1,962    1,962  100.0%  Circulaire      !! CRITIQUE
ARCHIVED LOG                    8,193    7,432   90.7%  Circulaire      !! CRITIQUE
BACKUP PIECE                      200      168   84.0%  Circulaire      Surveiller
BACKUP DATAFILE                 1,063      812   76.4%  Circulaire      Surveiller
DATAFILE                          512       42    8.2%  Permanente      OK

 Parametre CONTROL_FILE_RECORD_KEEP_TIME :

Parametre                                Valeur     Diagnostic
---------------------------------------- ---------- --------------------------------------------------
control_file_record_keep_time            7          OK (recommande : 7-30 jours)
```

---

### 3. v_incarnation_history.sql

**Objectif** : Historique RESETLOGS + SCN + fenetre PITR theorique

**Quand l'utiliser :**
- Identifier les incarnations passees apres RESETLOGS
- Calculer la fenetre PITR theorique (archives disponibles)
- Verifier le DBID (critique pour RMAN restore)

**Execution :**
```sql
SQL> @v_incarnation_history.sql
```

**Apercu du resultat :**
```
==================== INCARNATIONS - HISTORIQUE RESETLOGS ====================

Information                                   Valeur
--------------------------------------------- ---------------------------------------------
DBID (identifiant unique)                     1547283649
Checkpoint SCN courant                        12,847,569,234
Dernier RESETLOGS SCN                         8,234,156,789
Dernier RESETLOGS - Date                      15/02/2024 09:23:47

 Toutes les incarnations enregistrees :

Inc# Statut     Parent SCN debut         Date Reset           Flashback
---- ---------- ------ ---------------- -------------------- ----------
   1 PARENT          0    1,234,567,890 15/02/2024 09:23:47  NO
   2 PARENT          1    3,456,789,012 22/06/2024 14:18:32  NO
   3 CURRENT         2    8,234,156,789 15/02/2024 09:23:47  NO
```

---

### 4. v_recovery_readiness.sql

**Objectif** : Pre-flight check disaster recovery - "si crash maintenant, je peux recover ?"

**Quand l'utiliser :**
- Audit avant mise en production
- Verification post-modification de configuration
- Estimation RTO (Recovery Time Objective) selon scenarios

**Execution :**
```sql
SQL> @v_recovery_readiness.sql
```

**Apercu du resultat :**
```
==================== RECOVERY READINESS - SUIS-JE PRET ? ====================

Controle                                      Etat
--------------------------------------------- -------------------------------------------------------
Control Files - Nombre de copies              OK : 3 copies
Mode archivage (PITR possible ?)              OK : ARCHIVELOG (PITR possible)
Force Logging (operations NOLOGGING ?)        OK : FORCE LOGGING actif
DBID (necessaire pour RMAN)                   OK : DBID = 1547283649
Dernier archive log genere                    06/04/2026 18:42:15

 Estimation RTO (Recovery Time Objective) :

Scenario disaster                              RTO estime                     Prerequis
---------------------------------------------- ------------------------------ -------------------------
1 Control File perdu (multiplexe)              5 min (suppression init.ora)   >= 2 CF restants OK
Tous les CF perdus + Redo logs OK              30 min (CREATE CONTROLFILE)    Script BACKUP CF TO TRACE
Tous les CF + Redo logs perdus                 2-8h (recovery RMAN incomplet) Backup RMAN + DBID + archives
```

---

## Le concept cle : Le Control File est le cerveau de la base

| Element stocke dans le CF | Pourquoi c'est critique |
|---------------------------|------------------------|
| **DBID** | Identifiant unique - sans lui, RMAN restore impossible |
| **Checkpoint SCN** | Position de synchronisation memoire/disque |
| **Structure physique** | Chemins datafiles, redo logs, tablespaces |
| **Backup RMAN records** | Trace des backups (si pas de Recovery Catalog) |
| **RESETLOGS SCN** | Marqueur d'incarnations apres recovery incomplet |
| **Sequence #** | Compteur de versions (s'incremente a chaque modif structure) |

**La regle d'or :**
> 3 copies du Control File sur 3 disques differents. Pas 2 (paralysie d'arbitrage), pas 1 (perte = base inutilisable).
> Avec 3 copies, si 1 se corrompt, Oracle exclut automatiquement la mauvaise (tiebreaker majority vote).

---

## Pourquoi 3 copies et pas 2 ?

| Scenario | 2 copies | 3 copies |
|----------|----------|----------|
| 0 copie corrompue | OK | OK |
| **1 copie corrompue** | **!! BLOCAGE** (Oracle ne sait pas laquelle est la bonne) | **OK** (vote majoritaire : 2 contre 1) |
| 2 copies corrompues | Base perdue | !! BLOCAGE |
| 3 copies corrompues | N/A | Base perdue |

C'est le principe du **tiebreaker** : avec 3 copies, la majorite gagne automatiquement.

---

## Les 6 erreurs critiques liees aux Control Files

| Erreur | Cause | Gravite | Action |
|--------|-------|---------|--------|
| **2 copies au lieu de 3** | Configuration insuffisante | CRITIQUE | Ajouter 3eme copie sur disque different |
| **CONTROL_FILE_RECORD_KEEP_TIME = 0** | Mauvais reglage | CRITIQUE | Mettre 7-30 jours (defaut 7) |
| **Modification manuelle CF** | DBA inexperimente | FATAL | Ne JAMAIS toucher au CF |
| **Pas de script BACKUP CF TO TRACE** | Pas de DR plan | CRITIQUE | Generer regulierement le script |
| **RESETLOGS sans comprendre** | Recovery mal fait | WARNING | Comprendre incarnations avant |
| **RMAN AUTOBACKUP OFF** | Config par defaut | CRITIQUE | CONFIGURE CONTROLFILE AUTOBACKUP ON |

---

## FAQ du module

**Q: Combien de control files minimum en production ?**
> 3 copies sur 3 disques physiques differents. JAMAIS 2 (paralysie d'arbitrage) ou 1 (point unique de defaillance).

**Q: J'ai perdu un control file, que faire ?**
> 1. Identifier le CF perdu : `SELECT name, status FROM v$controlfile;`
> 2. Editer le SPFILE/init.ora pour retirer le CF perdu de CONTROL_FILES
> 3. STARTUP : la base demarre avec les copies restantes
> 4. Recreer le CF perdu en copiant depuis une copie valide (base STOPPED)

**Q: Quand utiliser RESETLOGS ?**
> Apres un recovery INCOMPLET (PITR, restore from backup avec perte de redo).
> Cree une nouvelle incarnation, reinitialise les sequences de redo logs.
> NORESETLOGS = continuation normale (recovery complet, tous les redo disponibles).

**Q: C'est quoi le DBID et pourquoi c'est critique ?**
> Identifiant unique de 10 chiffres genere a la creation. Necessaire pour RMAN RESTORE
> quand tu n'as plus de CF du tout. A noter dans le runbook DR sous peine de bloquer
> la recovery completement.

**Q: ORA-00245, c'est quoi ?**
> Erreur lors de l'AUTOBACKUP du CF : le CF est trop petit pour contenir les records.
> Solution : agrandir le CF ou reduire CONTROL_FILE_RECORD_KEEP_TIME.

---

## Vues Oracle utilisees

| Vue | Description |
|-----|-------------|
| `V$CONTROLFILE` | Liste des CF (nom, taille, statut, block_size) |
| `V$CONTROLFILE_RECORD_SECTION` | Sections internes (circulaires + permanentes, % utilise) |
| `V$DATABASE` | DBID, SCN, RESETLOGS, sequence CF, type CF |
| `V$DATABASE_INCARNATION` | Historique des incarnations (PARENT/CURRENT/ORPHAN) |
| `V$ARCHIVED_LOG` | Archives disponibles (fenetre PITR) |
| `V$BACKUP` | Datafiles en backup mode (BEGIN/END BACKUP) |
| `V$DATAFILE` | Statut datafiles (verification recovery) |
| `V$PARAMETER` | Parametre CONTROL_FILE_RECORD_KEEP_TIME |

---

## Pour aller plus loin

- **Theorie complete** : [Carrousel M1.8 sur LinkedIn](https://www.linkedin.com/posts/activity-7421450581426208768-oQXk)
- **Module precedent** : [M1.7 - Online Redo Logs et Archivelog](../M1.7-Online-Redo-Logs-Archivelog/)
- **Prochain module** : M1.9 - TEMP Tablespace
- **Documentation Oracle** : [Managing Control Files](https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/managing-control-files.html)

---

## A propos

**Auteur** : Omar SALL - DBA Oracle & Responsable Applications
**Experience** : 10+ ans en production critique (collectivites territoriales)
**Formation basee sur** : Formations ib Cegos (3000EUR+) + Livres Oracle 19c (ENI)

---

**#DBSentinelAcademy** | **#DBSA_M1_8** | Formation Oracle gratuite en francais
