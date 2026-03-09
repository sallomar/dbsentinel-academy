# M1.3 - Alert.log : Detecter les signaux faibles

> **DBSentinel Academy** - Formation Oracle gratuite en francais
> *Par Omar SALL - DBA Oracle 10+ ans production*

---

## Prerequis

- **Acces** : SYSDBA, SELECT ANY DICTIONARY ou SELECT_CATALOG_ROLE
- **Compatibilite** : Oracle 12c, 18c, 19c, 21c, 23ai

> **Nouveau sur Oracle ?** Consulte le [Guide Demarrage Complet](../../README.md#guide-demarrage-complet) dans le README principal.

---

## Les 3 scripts de ce module

### 1. check_alertlog.sql (RECOMMANDE pour commencer)

**Objectif** : Diagnostic rapide de l'alert.log en 1 execution

**Ce que tu vas voir :**
- Ou se trouve l'alert.log (chemin ADR)
- Combien de problemes/incidents actifs
- Les erreurs ORA- classees par gravite (les 4 groupes du carrousel)
- Les 5 derniers messages ORA- concrets

**Execution :**
```sql
SQL> @check_alertlog.sql
```

**Apercu du resultat :**
```
==================== ALERT.LOG - DIAGNOSTIC RAPIDE ====================

Information               Valeur
------------------------- ---------------------------------------------------------------------------
ADR Home                  /u01/app/oracle/diag/rdbms/orcl/ORCL
Diag Trace                /u01/app/oracle/diag/rdbms/orcl/ORCL/trace
Active Problem Count      1
Active Incident Count     2

 Erreurs ORA- par gravite (7 derniers jours) :
 (si aucune ligne = alert.log propre)

Gravite      Categorie                       Nb
------------ ------------------------------ ---
BLOQUANT     Espace disque sature             3
WARNING      Undo/Snapshot too old            2
INFO         Erreur Job Scheduler             8

 5 dernieres erreurs ORA- (message) :

Date/Heure     Code         Message
-------------- ------------ -------------------------------------------------------------------
04/03 14:22:15 ORA-01653    ORA-01653: unable to extend table HR.EMPLOYEES by 128 in ts USERS
04/03 06:00:02 ORA-12012    ORA-12012: error on auto execute of job "SYS"."ORA$AT_OS_OPT..."
03/03 09:15:42 ORA-01555    ORA-01555: snapshot too old: rollback segment number 8
01/03 18:05:33 ORA-01653    ORA-01653: unable to extend table APP.ORDERS by 64 in ts APP_DATA
01/03 06:00:03 ORA-12012    ORA-12012: error on auto execute of job "SYS"."ORA$AT_OS_OPT..."

 Temps reel : tail -f <Diag Trace>/alert_<SID>.log

=====================================================================
```

---

### 2. v_diag_info.sql

**Objectif** : Voir la structure complete de l'ADR (Automatic Diagnostic Repository)

**Quand l'utiliser :**
- Localiser les fichiers trace (.trc)
- Trouver le dossier des incidents Oracle
- Verifier la configuration diagnostique

**Execution :**
```sql
SQL> @v_diag_info.sql
```

**Apercu du resultat :**
```
==================== STRUCTURE ADR (Automatic Diagnostic Repository) ====================

Composant ADR             Chemin / Valeur
------------------------- --------------------------------------------------------------------------------
ADR Base                  /u01/app/oracle
ADR Home                  /u01/app/oracle/diag/rdbms/orcl/ORCL
Diag Trace                /u01/app/oracle/diag/rdbms/orcl/ORCL/trace
Diag Alert                /u01/app/oracle/diag/rdbms/orcl/ORCL/alert
Diag Incident             /u01/app/oracle/diag/rdbms/orcl/ORCL/incident
Diag Cdump                /u01/app/oracle/diag/rdbms/orcl/ORCL/cdump
Health Monitor            /u01/app/oracle/diag/rdbms/orcl/ORCL/hm
Default Trace File        /u01/app/oracle/diag/rdbms/orcl/ORCL/trace/ORCL_ora_12345.trc
Active Problem Count      1
Active Incident Count     2

 ADR Base      = Racine diagnostique Oracle
 Diag Trace    = Contient alert_SID.log + fichiers .trc
 Diag Alert    = Contient log.xml (format XML)
 Diag Incident = Incidents Oracle (ORA-600, ORA-7445)

========================================================================================
```

---

### 3. v_alert_errors.sql

**Objectif** : Analyser les erreurs ORA- sur 30 jours avec classification par gravite

**Quand l'utiliser :**
- Investigation apres un incident
- Audit periodique de sante
- Identifier les erreurs recurrentes
- Detecter les signaux de performance (checkpoint)

**Execution :**
```sql
SQL> @v_alert_errors.sql
```

**Apercu du resultat :**
```
==================== ERREURS ORA- : ANALYSE 30 JOURS ====================

Code ORA-     Nb Derniere fois     Diagnostic
------------ --- ---------------- -----------------------------------
ORA-01653      8 04/03/26 14:22   BLOQUANT - Tablespace plein
ORA-01555      5 03/03/26 09:15   WARNING  - Snapshot too old
ORA-00060      1 26/02/26 15:33   WARNING  - Deadlock detecte
ORA-12012     62 04/03/26 21:00   INFO     - Erreur job scheduler
ORA-06512     24 04/03/26 21:00   INFO     - Stack PL/SQL
ORA-04031      3 25/02/26 03:12   WARNING  - Shared Pool sature

 Signaux performance (30 derniers jours) :

Signal                           Nb Derniere fois
------------------------------ ---- ----------------
checkpoint not complete          15 02/03/26 22:45

 Actions par gravite :
 CRITIQUE : ORA-600, ORA-7445       --> Support Oracle immediat
 CRITIQUE : ORA-1578, ORA-312       --> Recovery RMAN
 BLOQUANT : ORA-1653, ORA-257       --> Etendre tablespace ou purger
 WARNING  : checkpoint not complete  --> Augmenter taille redo logs

=========================================================================
```

---

## Le concept cle : Alert.log = Boite noire Oracle

| Element | Description | Analogie |
|---------|-------------|----------|
| **Alert.log** | Journal texte de tous les evenements | Boite noire d'avion |
| **ADR** | Arborescence diagnostique (11g+) | Dossier medical complet |
| **Fichiers .trc** | Traces detaillees par processus | Radiographies |
| **log.xml** | Alert.log en format XML | Version structuree |
| **Incidents** | Erreurs critiques (ORA-600, ORA-7445) | Urgences medicales |

**La regle d'or :**
> Surveiller l'alert.log QUOTIDIENNEMENT = Anticiper les incidents 24-72h avant !

---

## Les 4 groupes d'alertes critiques

| Groupe | Erreurs | Gravite | Action |
|--------|---------|---------|--------|
| **Erreurs internes** | ORA-00600, ORA-07445 | CRITIQUE | Support Oracle |
| **Espace disque** | ORA-01653, ORA-00257 | BLOQUANT | Etendre ou purger |
| **Corruption** | ORA-01578, ORA-00312 | CRITIQUE | Recovery RMAN |
| **Performance** | checkpoint not complete | WARNING | Sizing redo logs |

---

## FAQ du module

**Q: Ou se trouve l'alert.log sur mon serveur ?**
> Execute `check_alertlog.sql` → la ligne "Diag Trace" donne le dossier.
> Le fichier s'appelle `alert_<SID>.log` dans ce dossier.

**Q: Comment surveiller l'alert.log en temps reel ?**
> `tail -f /chemin/alert_ORCL.log` ou avec ADRCI : `show alert -tail -f`

**Q: ORA-00600 c'est grave ?**
> Oui ! C'est un bug interne Oracle. Collecter les traces et contacter le support.
> Ne JAMAIS ignorer un ORA-600.

**Q: Mon alert.log fait 2 Go, c'est normal ?**
> Oui, il croit continuellement. Utiliser ADRCI pour purger :
> `adrci> purge -age 720 -type alert`

**Q: "checkpoint not complete" ca veut dire quoi ?**
> Oracle n'a pas fini d'ecrire les donnees avant le switch de redo log.
> Si frequent : tes redo logs sont trop petits → les agrandir.

---

## Vues Oracle utilisees

| Vue | Description |
|-----|-------------|
| `V$DIAG_INFO` | Chemins ADR et compteurs d'incidents |
| `V$DIAG_ALERT_EXT` | Contenu de l'alert.log (interrogeable en SQL) |

---

## Pour aller plus loin

- **Theorie complete** : [Carrousel M1.3 sur LinkedIn](https://www.linkedin.com/posts/activity-7408767001642287104-lwKf)
- **Module precedent** : [M1.2 - Les 5 Types de Fichiers Oracle](../M1.2-Types-Fichiers-Oracle/)
- **Prochain module** : M1.4 - Memoire Oracle (SGA/PGA)
- **Documentation Oracle** : [Managing Diagnostic Data](https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/managing-diagnostic-data.html)

---

## A propos

**Auteur** : Omar SALL - DBA Oracle & Responsable Applications
**Experience** : 10+ ans en production critique (collectivites territoriales)
**Formation basee sur** : Formations ib Cegos (3000EUR+) + Livres Oracle 19c (ENI)

---

**#DBSentinelAcademy** | **#DBSA_M1_3** | Formation Oracle gratuite en francais
