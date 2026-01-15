# M1.2 - Les 5 Types de Fichiers Oracle

> **DBSentinel Academy** - Formation Oracle gratuite en francais
> *Par Omar SALL - DBA Oracle 10+ ans production*

---

## Prerequis

- **Acces** : SYSDBA, SELECT ANY DICTIONARY ou SELECT_CATALOG_ROLE
- **Compatibilite** : Oracle 12c, 18c, 19c, 21c, 23ai

> **Nouveau sur Oracle ?** Consulte le [Guide Demarrage Complet](../../README.md#guide-demarrage-complet) dans le README principal.

---

## Les 5 scripts de ce module

### 1. check_all_files.sql (RECOMMANDE pour commencer)

**Objectif** : Vue synthetique de tous les fichiers de la base

**Ce que tu vas voir :**
- Les 5 types de fichiers Oracle (4 actifs + mode archives)
- Vue synthetique avec tailles et statut archivage

**Execution :**
```sql
SQL> @check_all_files.sql
```

**Apercu du resultat :**
```
==================== LES 5 TYPES DE FICHIERS ORACLE ====================

Type Fichier     Nb       Mo Role
--------------- --- -------- -----------------------------------
DATAFILES        24   88,534 Donnees permanentes
TEMPFILES         1    6,342 Donnees temporaires (tris)
REDO LOGS         6    1,200 Journalisation transactions
CONTROL FILES     2       25 Metadonnees base

Mode Archivage
---------------
ARCHIVELOG

========================================================================
```

---

### 2. v_datafiles.sql

**Objectif** : Liste detaillee des fichiers de donnees

**Quand l'utiliser :**
- Verifier l'espace utilise par tablespace
- Localiser un datafile specifique
- Diagnostiquer un probleme de stockage

**Execution :**
```sql
SQL> @v_datafiles.sql
```

**Apercu du resultat :**
```
==================== DATAFILES ====================

 ID Tablespace           Chemin Fichier                                           Mo Statut
--- -------------------- -------------------------------------------------------- ------- ----------
  1 SYSTEM               /u01/app/oracle/oradata/PROD/system01.dbf                  1,024 SYSTEM
  2 SYSAUX               /u01/app/oracle/oradata/PROD/sysaux01.dbf                    768 ONLINE
  3 UNDOTBS1             /u01/app/oracle/oradata/PROD/undotbs01.dbf                   512 ONLINE
  4 USERS                /u01/app/oracle/oradata/PROD/users01.dbf                     100 ONLINE
  5 DATA_APP             /u01/app/oracle/oradata/PROD/data_app01.dbf                2,048 ONLINE
  6 DATA_APP             /u01/app/oracle/oradata/PROD/data_app02.dbf                2,048 ONLINE

Tablespace           Nb       Mo
-------------------- --- --------
DATA_APP               2    4,096
SYSTEM                 1    1,024
SYSAUX                 1      768
UNDOTBS1               1      512
USERS                  1      100

Total Datafiles Taille Go
--------------- ---------
             24     88.53
```

---

### 3. v_tempfiles.sql

**Objectif** : Liste detaillee des fichiers temporaires

**Quand l'utiliser :**
- Verifier si le TEMP est sature (ORA-01652)
- Diagnostiquer des requetes lentes avec ORDER BY
- Planifier l'extension du tablespace TEMP

**Execution :**
```sql
SQL> @v_tempfiles.sql
```

**Apercu du resultat :**
```
==================== TEMPFILES ====================

 ID Tablespace      Chemin Fichier                                      Mo Statut
--- --------------- --------------------------------------------------- ------- ----------
  1 TEMP            /u01/app/oracle/oradata/PROD/temp01.dbf               6,342 ONLINE

Total Tempfiles Taille Go
--------------- ---------
              1      6.34
```

---

### 4. v_logfiles.sql

**Objectif** : Liste detaillee des Online Redo Logs

**Quand l'utiliser :**
- Verifier le multiplexage des redo logs
- Identifier le groupe CURRENT
- Diagnostiquer un probleme de demarrage

**Execution :**
```sql
SQL> @v_logfiles.sql
```

**Apercu du resultat :**
```
==================== REDO LOGS ====================

Grp  Seq#  Mo Statut     Chemin Membre                                   Mbr Status
--- ----- --- ---------- ------------------------------------------------ ------------
  1   142 200 INACTIVE   /u01/app/oracle/oradata/PROD/redo01a.log
  1   142 200 INACTIVE   /u02/app/oracle/oradata/PROD/redo01b.log
  2   143 200 CURRENT    /u01/app/oracle/oradata/PROD/redo02a.log
  2   143 200 CURRENT    /u02/app/oracle/oradata/PROD/redo02b.log
  3   141 200 INACTIVE   /u01/app/oracle/oradata/PROD/redo03a.log
  3   141 200 INACTIVE   /u02/app/oracle/oradata/PROD/redo03b.log

Groupes Membres Mo Total
------- ------- --------
      3       6      600
```

---

### 5. v_controlfiles.sql

**Objectif** : Liste detaillee des Control Files

**Quand l'utiliser :**
- Verifier le multiplexage (3 copies minimum)
- Localiser les control files
- Auditer la securite de la base

**Execution :**
```sql
SQL> @v_controlfiles.sql
```

**Apercu du resultat :**
```
==================== CONTROL FILES ====================

Chemin Control File                                                    Statut         Mo
---------------------------------------------------------------------- ---------- ------
/u01/app/oracle/oradata/PROD/control01.ctl                                        12.48
/u02/app/oracle/oradata/PROD/control02.ctl                                        12.48
/u03/app/oracle/fast_recovery_area/PROD/control03.ctl                             12.48

Multiplexage
-------------------------------------------------------
OK - 3 copies
```

---

## Le concept cle : Les 5 organes vitaux

| Type | Extension | Role | Analogie | Si perdu ? |
|------|-----------|------|----------|------------|
| **DATAFILES** | .dbf | Donnees permanentes | Coeur | Recovery RMAN |
| **TEMPFILES** | .dbf | Tris, jointures | Foie | Recreer (aucune perte) |
| **REDO LOGS** | .log | Journalisation | Memoire | Instance bloquee |
| **CONTROL FILES** | .ctl | Metadonnees | Cerveau | Base perdue |
| **ARCHIVES** | .arc | Historique | Historique medical | PITR impossible |

**La regle d'or :**
> Multiplexer Control Files et Redo Logs = Survivre a la corruption d'un fichier !

---

## FAQ du module

**Q: Pourquoi ma base fait 50 Go mais mes datafiles font 20 Go ?**
> Les 50 Go incluent : datafiles + tempfiles + redo logs + archives + control files.
> Execute `check_all_files.sql` pour voir la repartition.

**Q: Mon TEMP est sature a 100%, que faire ?**
> `ALTER TABLESPACE TEMP ADD TEMPFILE '/path/temp02.dbf' SIZE 2G;`
> Voir `v_tempfiles.sql` pour diagnostiquer.

**Q: Combien de control files dois-je avoir ?**
> Minimum 3, sur 3 disques differents. Un seul control file = danger critique.
> Execute `v_controlfiles.sql` pour verifier.

**Q: C'est quoi le statut CURRENT sur un redo log ?**
> C'est le groupe actif en cours d'ecriture. Oracle ecrit dedans en ce moment.

**Q: Un tempfile corrompu = perte de donnees ?**
> Non ! Le tempfile ne contient que des calculs temporaires.
> Supprime et recree le fichier, aucune perte.

---

## Vues Oracle utilisees

| Vue | Description |
|-----|-------------|
| `V$DATAFILE` | Fichiers de donnees (chemin, taille, statut) |
| `V$TEMPFILE` | Fichiers temporaires |
| `V$LOG` | Groupes de redo logs (statut, sequence) |
| `V$LOGFILE` | Membres des redo logs (chemins) |
| `V$CONTROLFILE` | Fichiers de controle |
| `V$TABLESPACE` | Tablespaces (liaison avec fichiers) |
| `V$DATABASE` | Mode archivage (ARCHIVELOG/NOARCHIVELOG) |

---

## Pour aller plus loin

- **Theorie complete** : [Carrousel M1.2 sur LinkedIn](https://www.linkedin.com/posts/activity-7406230295471013888-Weae)
- **Module precedent** : M1.1 - Instance vs Database
- **Prochain module** : M1.3 - Alert.log : Detecter les signaux faibles
- **Documentation Oracle** : [Managing Data Files](https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/managing-data-files-and-temp-files.html)

---

## A propos

**Auteur** : Omar SALL - DBA Oracle & Responsable Applications
**Experience** : 10+ ans en production critique (collectivites territoriales)
**Formation basee sur** : Formations ib Cegos (3000EUR+) + Livres Oracle 19c (ENI)

---

**#DBSentinelAcademy** | **#DBSA_M1_2** | Formation Oracle gratuite en francais
