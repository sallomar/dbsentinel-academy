# M1.1 - Instance vs Database

> **DBSentinel Academy** - Formation Oracle gratuite en francais
> *Par Omar SALL - DBA Oracle 10+ ans production*

---

## Prerequis

- **Acces** : SYSDBA, SELECT ANY DICTIONARY ou SELECT_CATALOG_ROLE
- **Compatibilite** : Oracle 12c, 18c, 19c, 21c, 23ai

> **Nouveau sur Oracle ?** Consulte le [Guide Demarrage Complet](../../README.md#guide-demarrage-complet) dans le README principal.

---

## Les 3 scripts de ce module

### 1. check_instance_vs_db.sql (RECOMMANDE pour commencer)

**Objectif** : Voir la difference entre Instance et Database en 1 execution

**Ce que tu vas apprendre :**
- Qu'est-ce qui tourne en MEMOIRE (instance)
- Qu'est-ce qui est sur le DISQUE (database)
- Pourquoi SHUTDOWN ne supprime PAS tes donnees

**Execution :**
```sql
SQL> @check_instance_vs_db.sql
```

**Apercu du resultat :**
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

### 2. v_instance_status.sql

**Objectif** : Connaitre l'etat detaille de l'instance

**Quand l'utiliser :**
- Verifier si l'instance est demarree
- Voir depuis quand elle tourne
- Savoir si les connexions sont autorisees

**Execution :**
```sql
SQL> @v_instance_status.sql
```

**Apercu du resultat :**
```
================== ETAT INSTANCE ==================

Instance     Statut   Demarrage            Serveur              Version
------------ -------- -------------------- -------------------- ---------------
ORCL         OPEN     14/01/2026 08:15:32  srv-oracle-prod      19.0.0.0.0

 Statut : OPEN=OK | MOUNTED=Maintenance | STARTED=En demarrage

===================================================
```

---

### 3. v_database_status.sql

**Objectif** : Connaitre l'etat detaille de la database

**Quand l'utiliser :**
- Verifier le mode d'ouverture (READ WRITE, READ ONLY)
- Voir si ARCHIVELOG est active
- Connaitre le role (PRIMARY, STANDBY)

**Execution :**
```sql
SQL> @v_database_status.sql
```

**Apercu du resultat :**
```
================== ETAT DATABASE ==================

      DBID Base       Mode         Archivage    Role             Creation
---------- ---------- ------------ ------------ ---------------- ------------
1234567890 ORCL       READ WRITE   ARCHIVELOG   PRIMARY          15/06/2023

 Mode     : READ WRITE=Prod | READ ONLY=Standby | MOUNTED=Maintenance
 Archivage: ARCHIVELOG=Backup chaud | NOARCHIVELOG=Backup froid

===================================================
```

---

## Le concept cle : Instance vs Database

| | INSTANCE | DATABASE |
|--|----------|----------|
| **C'est quoi ?** | Memoire + Processus | Fichiers sur disque |
| **Composants** | SGA, PGA, PMON, SMON... | .dbf, .log, .ctl |
| **Persistence** | TEMPORAIRE | PERMANENT |
| **Au SHUTDOWN** | Disparait | Reste intact |
| **Analogie** | Moteur qui tourne | Voiture dans le garage |

**La regle d'or :**
> SHUTDOWN = Eteindre le moteur, PAS detruire la voiture !
> Tes donnees sont EN SECURITE apres un SHUTDOWN.

---

## FAQ du module

**Q: J'ai fait SHUTDOWN, j'ai perdu mes donnees ?**
> Non ! Tes fichiers (.dbf, .log, .ctl) sont toujours sur le disque.
> Fais `STARTUP` pour redemarrer l'instance et acceder a tes donnees.

**Q: C'est quoi la difference entre SHUTDOWN et DROP DATABASE ?**
> - SHUTDOWN = Eteindre (reversible, donnees intactes)
> - DROP DATABASE = Supprimer definitivement (IRREVERSIBLE !)

**Q: Comment savoir si ma base est en ARCHIVELOG ?**
> Execute `v_database_status.sql` et regarde la colonne "Archivage".

**Q: Une instance peut gerer plusieurs databases ?**
> Non (sauf RAC). C'est une relation 1:1 en architecture standard.
> L'instance lit les fichiers d'UNE SEULE database.

**Q: La SGA et la PGA, c'est quoi exactement ?**
> - **SGA** (System Global Area) : Memoire PARTAGEE entre tous les utilisateurs
> - **PGA** (Program Global Area) : Memoire PRIVEE pour chaque session
> Le module M1.4 approfondit ce sujet.

---

## Vues Oracle utilisees

| Vue | Description |
|-----|-------------|
| `V$INSTANCE` | Informations sur l'instance (nom, statut, demarrage) |
| `V$DATABASE` | Informations sur la database (nom, mode, archivage) |
| `V$SGA` | Composants et tailles de la SGA |
| `V$PGASTAT` | Statistiques de la PGA |
| `V$BGPROCESS` | Processus background actifs |
| `V$DATAFILE` | Fichiers de donnees |
| `V$LOG` | Groupes de redo logs |
| `V$CONTROLFILE` | Fichiers de controle |
| `V$TEMPFILE` | Fichiers temporaires |

---

## Pour aller plus loin

- **Theorie complete** : [Carrousel M1.1 sur LinkedIn](https://www.linkedin.com/posts/activity-7404830055090032641-W67c)
- **Prochain module** : M1.2 - Les 5 Types de Fichiers Oracle
- **Documentation Oracle** : [Oracle 19c Concepts](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/)

---

## A propos

**Auteur** : Omar SALL - DBA Oracle & Responsable Applications
**Experience** : 10+ ans en production critique (collectivites territoriales)
**Formation basee sur** : Formations ib Cegos (3000EUR+) + Livres Oracle 19c (ENI)

---

**#DBSentinelAcademy** | **#DBSA_M1_1** | Formation Oracle gratuite en francais
