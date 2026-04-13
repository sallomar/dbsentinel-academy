# M1.6 - Tablespaces et Datafiles

> **DBSentinel Academy** - Formation Oracle gratuite en francais
> *Par Omar SALL - DBA Oracle 10+ ans production*

---

## Prerequis

- **Acces** : SYSDBA, SELECT ANY DICTIONARY ou SELECT_CATALOG_ROLE
- **Compatibilite** : Oracle 12c, 18c, 19c, 21c, 23ai

> **Nouveau sur Oracle ?** Consulte le [Guide Demarrage Complet](../../README.md#guide-demarrage-complet) dans le README principal.

---

## Les 4 scripts de ce module

### 1. check_tablespaces.sql (RECOMMANDE pour commencer)

**Objectif** : Dashboard rapide de tous les tablespaces avec % utilise et alertes

**Ce que tu vas voir :**
- Tous les tablespaces (permanents, undo, temporaires) avec taille et % utilise
- Statut intelligent base sur % Max (capacite reelle vs autoextend)
- Resume global : nombre de tablespaces, datafiles, espace total alloue

**Execution :**
```sql
SQL> @check_tablespaces.sql
```

**Apercu du resultat :**
```
==================== TABLESPACES - DIAGNOSTIC RAPIDE ====================

Tablespace           Type       Taille       Utilise      Libre        % Util  Max (Auto)   % Max   Statut
-------------------- ---------- ------------ ------------ ------------ ------- ------------ ------- ------------
APP_DATA             PERMANENT       2,000       1,750          250   87.5%      64.0 GB    2.7%  OK
SYSTEM               PERMANENT         850         680          170   80.0%      32.0 GB    2.1%  OK
APP_INDEX            PERMANENT       1,200         860          340   71.7%      32.0 GB    2.6%  OK
SYSAUX               PERMANENT         600         420          180   70.0%      32.0 GB    1.3%  OK
USERS                PERMANENT         500         225          275   45.0%      32.0 GB    0.7%  OK
UNDOTBS1             UNDO              200          60          140   30.0%      32.0 GB    0.2%  OK

 Resume tablespaces :

Information                         Valeur
----------------------------------- --------------------
Tablespaces permanents              5
Tablespaces temporaires             1
Tablespaces UNDO                    1
Total fichiers (data + temp)        8
Espace total alloue (data + temp)  11.5 GB
```

---

### 2. v_space_usage.sql

**Objectif** : Analyse detaillee espace actuel vs capacite maximale (AUTOEXTEND)

**Quand l'utiliser :**
- Verifier la marge reelle avant ORA-01653
- Identifier les tablespaces sans AUTOEXTEND (risque)
- Planifier les extensions de tablespace

**Execution :**
```sql
SQL> @v_space_usage.sql
```

**Apercu du resultat :**
```
==================== ESPACE TABLESPACES - CAPACITE MAXIMALE ====================

Tablespace           Actuel       Utilise      Libre        % Util  Max (Auto)   Marge        AutoExt
-------------------- ------------ ------------ ------------ ------- ------------ ------------ --------
APP_DATA                  2,000       1,750          250   87.5%      65,536      63,786  OUI
SYSTEM                      850         680          170   80.0%      32,768      32,088  OUI
APP_INDEX                 1,200         860          340   71.7%      32,768      31,908  OUI
SYSAUX                      600         420          180   70.0%      32,768      32,348  OUI
USERS                       500         225          275   45.0%      32,768      32,543  OUI
UNDOTBS1                    200          60          140   30.0%      32,768      32,708  OUI

 Datafiles sans AUTOEXTEND (risque ORA-01653) :

Tablespace           Datafile                                                Taille
-------------------- ------------------------------------------------------- ----------
```

---

### 3. v_datafile_details.sql

**Objectif** : Detail de chaque datafile avec AUTOEXTEND, MAXSIZE et increment

**Quand l'utiliser :**
- Voir la correspondance tablespace / datafiles (logique / physique)
- Verifier la configuration AUTOEXTEND par fichier
- Identifier les datafiles a leur limite de taille

**Execution :**
```sql
SQL> @v_datafile_details.sql
```

**Apercu du resultat :**
```
==================== DATAFILES - DETAIL PAR TABLESPACE ====================

Tablespace             ID Datafile                                                  Taille     Auto Max        Increment    Statut
-------------------- ---- --------------------------------------------------------- ---------- ---- ---------- ------------ ----------
APP_DATA                5 /u01/oradata/ORCL/app_data01.dbf                             1,000 OUI      32,768       10 MB AVAILABLE
APP_DATA                6 /u01/oradata/ORCL/app_data02.dbf                             1,000 OUI      32,768       10 MB AVAILABLE
APP_INDEX               7 /u01/oradata/ORCL/app_index01.dbf                            1,200 OUI      32,768       10 MB AVAILABLE
SYSTEM                  1 /u01/oradata/ORCL/system01.dbf                                 850 OUI      32,768       10 MB AVAILABLE
```

---

### 4. v_segment_top.sql

**Objectif** : Top 20 objets par taille + repartition espace par type et schema

**Quand l'utiliser :**
- Identifier quel objet consomme le plus d'espace
- Comprendre la repartition tables vs index vs LOB
- Detecter les schemas applicatifs les plus gourmands

**Execution :**
```sql
SQL> @v_segment_top.sql
```

**Apercu du resultat :**
```
==================== TOP SEGMENTS - QUI CONSOMME L'ESPACE ====================

  # Schema          Objet                          Type       Tablespace           Taille
--- --------------- ------------------------------ ---------- -------------------- ------------
  1 APP_PAIE        BULLETIN_PAIE                  TABLE      APP_DATA                  450.0
  2 APP_PAIE        IDX_BULLETIN_DATE              INDEX      APP_INDEX                 280.0
  3 HR_ADMIN        EMPLOYES_HISTORIQUE             TABLE      APP_DATA                  220.0
  4 APP_PAIE        IDX_BULLETIN_AGENT             INDEX      APP_INDEX                 195.0
  5 COMPTA          ECRITURES_COMPTABLES           TABLE      APP_DATA                  180.0

 Repartition par type de segment :

Type Segment              Nb Total        % Total
-------------------- ------- ------------ --------
TABLE                    245      1,398     55.2%
INDEX                    312        891     35.2%
LOBSEGMENT                18        142      5.6%
```

---

## Le concept cle : Logique vs Physique

| Niveau | Element | Analogie | Exemple |
|--------|---------|----------|---------|
| **LOGIQUE** | Tablespace | Immeuble (adresse) | APP_DATA, USERS, TEMP |
| **PHYSIQUE** | Datafile | Etage (stockage reel) | app_data01.dbf, users01.dbf |
| **LOGIQUE** | Segment | Appartement (objet) | TABLE, INDEX, LOB |
| **LOGIQUE** | Extent | Piece (allocation) | Groupe de blocs contigus |
| **PHYSIQUE** | Block | Brique (unite I/O) | 8 KB par defaut |

**La regle d'or :**
> 1 tablespace = 1 ou plusieurs datafiles. Le DBA gere les tablespaces (logique).
> Oracle gere les blocs dans les datafiles (physique). Ne jamais creer d'objets dans SYSTEM !

---

## Les 5 tablespaces obligatoires

| Tablespace | Contenu | Si plein |
|------------|---------|----------|
| **SYSTEM** | Dictionnaire de donnees (metadata Oracle) | Instance inutilisable |
| **SYSAUX** | Composants auxiliaires (AWR, ADDM, RMAN) | Perte monitoring |
| **USERS** | Donnees utilisateurs (defaut) | ORA-01653 |
| **TEMP** | Tris, jointures, GROUP BY temporaires | Sessions bloquees |
| **UNDO** | Rollback, coherence lecture (MVCC) | ORA-01555, transactions bloquees |

---

## FAQ du module

**Q: ORA-01653 en production, que faire en urgence ?**
> 1. `@check_tablespaces.sql` → Identifier le tablespace plein
> 2. `@v_space_usage.sql` → Verifier si AUTOEXTEND est actif
> 3. Si AUTOEXTEND OFF : `ALTER DATABASE DATAFILE 'fichier.dbf' AUTOEXTEND ON MAXSIZE 32G;`
> 4. Si plus de place : `ALTER TABLESPACE ts ADD DATAFILE '/u01/oradata/ORCL/ts02.dbf' SIZE 1G AUTOEXTEND ON;`

**Q: Faut-il activer AUTOEXTEND sur SYSTEM ?**
> Non recommande. SYSTEM ne devrait pas grossir en production.
> Si SYSTEM grossit, c'est souvent un probleme (objets crees au mauvais endroit).

**Q: Combien de datafiles par tablespace ?**
> Pas de regle absolue. En pratique : 1 a 4 fichiers de 1-10 GB chacun.
> Eviter les fichiers > 32 GB (backup plus long, recovery plus lent).

**Q: TEMP plein, que faire ?**
> Le TEMP se vide automatiquement quand les sessions terminent leurs tris.
> Si persistant : identifier les requetes gourmandes avec V$TEMPSEG_USAGE.
> En urgence : `ALTER TABLESPACE TEMP ADD TEMPFILE '/u01/oradata/ORCL/temp02.dbf' SIZE 2G;`

**Q: Comment savoir si un tablespace est en BIGFILE ?**
> `SELECT tablespace_name, bigfile FROM dba_tablespaces;`
> BIGFILE = 1 seul datafile geant (jusqu'a 128 TB). Utilise rarement sauf ASM.

---

## Vues Oracle utilisees

| Vue | Description |
|-----|-------------|
| `DBA_TABLESPACES` | Tous les tablespaces (type, statut, bigfile) |
| `DBA_DATA_FILES` | Datafiles permanents (taille, autoextend, maxsize) |
| `DBA_TEMP_FREE_SPACE` | Espace libre dans les tablespaces temporaires |
| `DBA_FREE_SPACE` | Espace libre dans les tablespaces permanents |
| `DBA_SEGMENTS` | Tous les segments (tables, index, LOB) avec taille |
| `V$DATAFILE` | Infos physiques datafiles (statut, checkpoint) |
| `V$PARAMETER` | Parametres instance (db_block_size) |

---

## Pour aller plus loin

- **Theorie complete** : [Carrousel M1.6 sur LinkedIn](https://www.linkedin.com/posts/activity-7416377171096670208-K9Ug)
- **Module precedent** : [M1.5 - Processus Background Oracle](../M1.5-Processus-Background/)
- **Prochain module** : M1.7 - Online Redo Logs et Archivelog
- **Documentation Oracle** : [Tablespaces and Datafiles](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/logical-storage-structures.html)

---

## A propos

**Auteur** : Omar SALL - DBA Oracle & Responsable Applications
**Experience** : 10+ ans en production critique (collectivites territoriales)
**Formation basee sur** : Formations ib Cegos (3000EUR+) + Livres Oracle 19c (ENI)

---

**#DBSentinelAcademy** | **#DBSA_M1_6** | Formation Oracle gratuite en francais
