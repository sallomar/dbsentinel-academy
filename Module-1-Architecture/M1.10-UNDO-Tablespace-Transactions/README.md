# M1.10 - UNDO Tablespace et Transactions

> **DBSentinel Academy** - Formation Oracle gratuite en francais
> *Par Omar SALL - DBA Oracle 10+ ans production*

---

## Prerequis

- **Acces** : SYSDBA, SELECT ANY DICTIONARY ou SELECT_CATALOG_ROLE
- **Compatibilite** : Oracle 12c, 18c, 19c, 21c, 23ai

> **Nouveau sur Oracle ?** Consulte le [Guide Demarrage Complet](../../README.md#guide-demarrage-complet) dans le README principal.

---

## Les 4 scripts de ce module

### 1. check_undo.sql (RECOMMANDE pour commencer)

**Objectif** : Dashboard UNDO - espace par datafile + etat des blocs + configuration

**Ce que tu vas voir :**
- Detail de chaque datafile UNDO (alloue, utilise, AUTOEXTEND, % Max)
- Repartition de l'espace par statut (ACTIVE / UNEXPIRED / EXPIRED)
- Configuration : UNDO_MANAGEMENT, UNDO_RETENTION, retention tunee, GUARANTEE

**Execution :**
```sql
SQL> @check_undo.sql
```

**Apercu du resultat :**
```
==================== UNDO TABLESPACE - DIAGNOSTIC RAPIDE ====================

Tablespace           Datafile UNDO                          Alloue    Utilise   % Util  Max (Auto) % Max   Statut
-------------------- -------------------------------------- --------- --------- ------- ---------- ------- ------
UNDOTBS1             /u01/oradata/ORCL/undotbs01.dbf            4,096     1,408   34.4%    16.0 GB    8.6%  OK
UNDOTBS1             /u02/oradata/ORCL/undotbs02.dbf            4,096     1,152   28.1%    16.0 GB    7.0%  OK

 Repartition de l'espace UNDO par statut de bloc :

Etat bloc UNDO   Taille       % UNDO   Signification
---------------- ------------ -------- ----------------------------------------
EXPIRED             3,200 MB    55.6%  Recyclable (hors retention)
ACTIVE              1,344 MB    23.3%  Transactions en cours (non committees)
UNEXPIRED           1,216 MB    21.1%  Conserve (dans UNDO_RETENTION)
```

---

### 2. v_undo_transactions.sql

**Objectif** : Identifier les transactions actives qui consomment l'UNDO + SQL_ID

**Quand l'utiliser :**
- Reperer une transaction longue qui bloque le recyclage de l'UNDO
- Evaluer le cout d'un KILL SESSION (rollback long si gros UNDO)
- Comprendre quel segment de rollback porte la charge

**Execution :**
```sql
SQL> @v_undo_transactions.sql
```

**Apercu du resultat :**
```
==================== UNDO - TRANSACTIONS ACTIVES ====================

SID,Serial     Utilisateur     Programme              Duree     UNDO genere  Lignes UNDO  SQL_ID
-------------- --------------- ---------------------- --------- ------------ ------------ --------------
118,40872      APP_PAIE        sqlplus.exe              3h12m    1,152.0 MB    3,612,000  7g9hauknq3p2x
204,15533      HR_ADMIN        JDBC Thin Client         0h12m      144.0 MB      412,500  3kfnz8wptr5ab
77,28104       BATCH_USER      python.exe               0h04m       48.0 MB       98,200  9xmqp2lhc7vt0
```

---

### 3. v_undo_sizing.sql

**Objectif** : Calculer le dimensionnement UNDO recommande (formule V$UNDOSTAT)

**Quand l'utiliser :**
- Valider la taille du tablespace UNDO avant production
- Justifier une extension UNDO ou une retention plus longue
- Anticiper l'impact d'un batch nocturne sur l'UNDO

**Execution :**
```sql
SQL> @v_undo_sizing.sql
```

**Apercu du resultat :**
```
==================== UNDO - SIZING ET RECOMMANDATIONS ====================

Element                                    Valeur     Recommandation
------------------------------------------ ---------- ----------------------------------------
UNDO actuellement alloue                      8.0 GB  -
UNDO max (avec AUTOEXTEND)                    32.0 GB  -
UNDO requis (retention configuree)            0.9 GB  OK : capacite max suffisante
UNDO requis + marge securite (x1.5)           1.3 GB  OK : optimal avec marge
Retention min conseillee (MAXQUERYLEN +20%)  2,902 s  !! Risque ORA-01555 sur requetes longues
```

---

### 4. v_ora01555_diag.sql

**Objectif** : Diagnostiquer les erreurs ORA-01555 et ORA-30036 sur l'historique UNDO

**Quand l'utiliser :**
- Apres un ORA-01555 signale par un batch ou un rapport
- Pour reperer les creneaux a risque (requetes longues vs retention)
- Pour decider entre : rallonger la retention ou optimiser la requete

**Execution :**
```sql
SQL> @v_ora01555_diag.sql
```

**Apercu du resultat :**
```
============== DIAGNOSTIC ORA-01555 / ORA-30036 (V$UNDOSTAT) ==============

Indicateur sur la periode                        Valeur     Verdict
------------------------------------------------ ---------- ----------------------------------------
Total ORA-01555 (snapshot too old)                    3     !! Retention trop courte / UNDO recycle
Total ORA-30036 (unable to extend)                    0     OK : aucune erreur d'espace
Requete la plus longue observee                 2,418 s     A comparer a UNDO_RETENTION
UNDO_RETENTION configure                          900 s     !! Inferieur a la requete la plus longue
```

---

## Le concept cle : UNDO = la gomme + la photo instantanee

| Role de l'UNDO | A quoi ca sert |
|----------------|----------------|
| **Rollback** | Annuler une transaction (ROLLBACK ou crash) avec le before-image |
| **Read Consistency** | Reconstruire une vue coherente pendant qu'une autre session modifie |
| **Flashback Query** | Lire les donnees `AS OF TIMESTAMP` dans le passe |
| **Recovery** | Annuler les transactions non committees apres un crash instance |

**UNDO vs REDO (a ne jamais confondre) :**
> **UNDO** = Before-image (l'etat AVANT) -> sert a **ANNULER**. Tablespace UNDO, recyclable.
> **REDO** = After-image (l'etat APRES) -> sert a **REJOUER**. Online Redo Logs, archive.
> Augmenter l'UNDO ne resout jamais un probleme de recovery, et inversement.

---

## Les 6 pieges classiques de l'UNDO

| Erreur | Cause | Gravite | Action |
|--------|-------|---------|--------|
| **ORA-01555** | UNDO_RETENTION < duree requete | CRITIQUE | Augmenter retention (> MAXQUERYLEN + 20%) |
| **ORA-30036** | UNDO plein (souvent GUARANTEE) | CRITIQUE | Etendre tablespace UNDO / revoir GUARANTEE |
| **Retention trop courte** | Defaut 900s (15 min) garde | WARNING | Ajuster selon MAXQUERYLEN de V$UNDOSTAT |
| **AUTOEXTEND OFF** | MAXSIZE atteint silencieusement | CRITIQUE | `ALTER DATABASE DATAFILE ... AUTOEXTEND ON` |
| **Transaction longue oubliee** | Batch jamais committe | WARNING | Reperer via v_undo_transactions, COMMIT/ROLLBACK |
| **Batch sans ajuster retention** | Batch 4h, retention 15min | CRITIQUE | `ALTER SYSTEM SET UNDO_RETENTION` pre-batch |

---

## FAQ du module

**Q: ORA-01555 sur mon batch de nuit, que faire ?**
> 1. `@v_ora01555_diag.sql` -> confirmer SSOLDERRCNT et comparer MAXQUERYLEN vs retention
> 2. `SHOW PARAMETER undo_retention` -> verifier la valeur configuree
> 3. `ALTER SYSTEM SET UNDO_RETENTION = 18000;` (5h, marge pour un batch 4h)
> 4. `@v_undo_sizing.sql` -> verifier que l'UNDO peut absorber cette retention
> 5. Relancer le batch. Apres : remettre la retention normale si souhaite.

**Q: Quelle difference entre UNDO_RETENTION et la retention "tunee" ?**
> UNDO_RETENTION est ta **cible**. Si le tablespace est en AUTOEXTEND, Oracle calcule
> une retention reelle (TUNED_UNDORETENTION dans V$UNDOSTAT) souvent **superieure**.
> Sans RETENTION GUARANTEE, Oracle peut quand meme recycler l'UNDO sous pression d'espace.

**Q: Faut-il activer RETENTION GUARANTEE ?**
> Seulement si des Flashback Queries sont **critiques pour le metier**. Attention : avec
> GUARANTEE, si l'UNDO manque d'espace, ce sont les **transactions** qui echouent (ORA-30036)
> au lieu de l'UNDO qui se recycle. Agrandis le tablespace UNDO d'abord.

**Q: Une transaction tourne depuis 3h, je peux la killer ?**
> Oui, mais `KILL SESSION` declenche un **ROLLBACK** qui relit tout l'UNDO genere.
> Avec 1,1 GB d'UNDO (cf. v_undo_transactions), le rollback peut durer longtemps.
> Surveille `V$TRANSACTION.USED_UBLK` qui doit decroitre pendant le rollback.

**Q: Combien de tablespaces UNDO faut-il ?**
> Un seul **actif** a la fois (parametre UNDO_TABLESPACE). On peut en avoir un second
> pour basculer sans interruption (`ALTER SYSTEM SET UNDO_TABLESPACE=undotbs2`),
> utile pour redimensionner ou defragmenter l'UNDO.

**Q: Le tablespace UNDO se remplit, c'est grave ?**
> Pas forcement. Les blocs EXPIRED sont **recyclables** : Oracle les reutilise.
> Le vrai risque est la part ACTIVE + UNEXPIRED qui approche de la capacite MAX (% Max).
> C'est ce que `check_undo.sql` surveille.

---

## Vues Oracle utilisees

| Vue | Description |
|-----|-------------|
| `DBA_DATA_FILES` | Datafiles du tablespace UNDO (taille, autoextend, maxbytes) |
| `DBA_TABLESPACES` | Type CONTENTS = UNDO + statut RETENTION (GUARANTEE/NOGUARANTEE) |
| `DBA_UNDO_EXTENTS` | Etat des extents UNDO (ACTIVE / UNEXPIRED / EXPIRED) par fichier |
| `V$TRANSACTION` | Transactions actives : blocs UNDO (USED_UBLK), lignes (USED_UREC) |
| `V$SESSION` | Identification utilisateur, programme, SQL_ID |
| `V$ROLLNAME` | Nom des segments de rollback (UNDO) |
| `V$UNDOSTAT` | Stats UNDO par intervalle 10 min : UNDOBLKS, MAXQUERYLEN, SSOLDERRCNT, NOSPACEERRCNT, TUNED_UNDORETENTION |
| `V$PARAMETER` | UNDO_MANAGEMENT, UNDO_TABLESPACE, UNDO_RETENTION, DB_BLOCK_SIZE |

---

## Pour aller plus loin

- **Theorie complete** : [Carrousel M1.10 sur LinkedIn](https://www.linkedin.com/posts/activity-7426524022303129600-SBQ7)
- **Module precedent** : [M1.9 - TEMP Tablespace](../M1.9-TEMP-Tablespace/)
- **Prochain module** : M1.11 - Schemas et Utilisateurs Oracle
- **Documentation Oracle** : [Managing Undo](https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/managing-undo.html)

---

## A propos

**Auteur** : Omar SALL - DBA Oracle & Responsable Applications
**Experience** : 10+ ans en production critique (collectivites territoriales)
**Formation basee sur** : Formations ib Cegos (3000EUR+) + Livres Oracle 19c (ENI)

---

**#DBSentinelAcademy** | **#DBSA_M1_10** | Formation Oracle gratuite en francais
