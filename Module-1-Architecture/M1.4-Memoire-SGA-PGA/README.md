# M1.4 - Memoire Oracle : SGA et PGA

> **DBSentinel Academy** - Formation Oracle gratuite en francais
> *Par Omar SALL - DBA Oracle 10+ ans production*

---

## Prerequis

- **Acces** : SYSDBA, SELECT ANY DICTIONARY ou SELECT_CATALOG_ROLE
- **Compatibilite** : Oracle 12c, 18c, 19c, 21c, 23ai

> **Nouveau sur Oracle ?** Consulte le [Guide Demarrage Complet](../../README.md#guide-demarrage-complet) dans le README principal.

---

## Les 3 scripts de ce module

### 1. check_memory.sql (RECOMMANDE pour commencer)

**Objectif** : Dashboard memoire SGA + PGA en 1 execution

**Ce que tu vas voir :**
- Repartition memoire globale (SGA + PGA + total)
- Les 3 composants SGA principaux (Buffer Cache, Shared Pool, Redo Buffer)
- Sante PGA avec detection de saturation et risque ORA-04030
- PGA moyenne par session (alerte si < 5 MB)

**Execution :**
```sql
SQL> @check_memory.sql
```

**Apercu du resultat :**
```
==================== MEMOIRE ORACLE - DIAGNOSTIC RAPIDE ====================

Composant                      Taille       Detail
------------------------------ ------------ --------------------------------------------------
SGA (Memoire partagee)              4.0 GB  Parametre : SGA_TARGET
PGA (Memoire privee)               824 MB  Parametre : PGA_AGGREGATE_TARGET
--- TOTAL MEMOIRE ---              4.8 GB  45 sessions (12 actives)

 Composants SGA principaux :

Composant SGA                  Taille       % SGA
------------------------------ ------------ --------
Buffer Cache (donnees)              2.6 GB     66%
Shared Pool (SQL/metadata)          1.1 GB     28%
Large Pool                         128 MB      3%
Redo Log Buffer                     16 MB

 Sante PGA (risque ORA-04030) :

Indicateur                          Valeur          Statut
----------------------------------- --------------- -------------------------
PGA cible (target)                       2.0 GB
PGA allouee actuellement               824 MB      OK
PGA max atteinte                     1,456 MB
Over allocation count                       0       OK (aucun depassement)
PGA moyenne par session                  18.3 MB    OK

 Regles de sizing (rappel) :
 SGA recommandee  = 50% RAM serveur
 PGA recommandee  = 20-25% RAM serveur
 SGA + PGA        < 80% RAM serveur (laisser place a l'OS)

 ORA-04030 = PGA saturee --> Augmenter PGA_AGGREGATE_TARGET
 I/O excessifs = SGA trop petite --> Augmenter SGA_TARGET

========================================================================
```

---

### 2. v_sga_detail.sql

**Objectif** : Analyse SGA complete avec efficacite Buffer Cache et conseil Oracle

**Quand l'utiliser :**
- Verifier la repartition interne de la SGA (Buffer Cache vs Shared Pool)
- Mesurer le Buffer Cache Hit Ratio (objectif : >= 95%)
- Utiliser V$SGA_TARGET_ADVICE pour savoir si la SGA est bien dimensionnee
- Verifier l'auto-tuning ASMM (nombre de resizes)

**Execution :**
```sql
SQL> @v_sga_detail.sql
```

**Apercu du resultat :**
```
==================== SGA - ANALYSE DETAILLEE ====================

Composant                           Taille
----------------------------------- ------------
Maximum SGA Size                        4.0 GB
Shared Pool Size                        1.7 GB
Buffer Cache Size                       1.3 GB
Startup overhead in Shared Pool        200 MB
Shared IO Pool Size                    128 MB
Streams Pool Size                       32 MB
Large Pool Size                         16 MB
Granule Size                            16 MB
Fixed SGA Size                           9 MB
Redo Buffers                             7 MB

 Composants dynamiques (ASMM - Auto Shared Memory Management) :

Composant                      Actuel       Min          Max atteint  Resizes
------------------------------ ------------ ------------ ------------ -------
shared pool                         1.7 GB       1.7 GB       1.7 GB      0
DEFAULT buffer cache                1.2 GB       1.2 GB       1.2 GB      0
Shared IO Pool                     128 MB       128 MB       128 MB      0
streams pool                        32 MB        32 MB        32 MB      0
large pool                          16 MB        16 MB        16 MB      0

 Efficacite Buffer Cache :

Metrique                            Valeur          Diagnostic
----------------------------------- --------------- ------------------------------
Buffer Cache Hit Ratio                 97.54%       BON (>= 95%)

 Conseil Oracle (V$SGA_TARGET_ADVICE) :
 (DB Time Factor < 1 = amelioration si SGA plus grande)

SGA          Factor     DB Time %    Conseil
------------ ---------- ------------ -------------------------
       1.5 GB  0.50              178  Degradation
       2.3 GB  0.75              100
       3.0 GB  1.00              100  --> CONFIG ACTUELLE
       3.8 GB  1.25              100
       4.5 GB  1.50              100
       6.0 GB  2.00              100

 Actions :
 Hit Ratio < 95%         --> Augmenter SGA_TARGET (Buffer Cache)
 Shared Pool saturation  --> Verifier curseurs non partages
 Factor < 1 (advice)     --> SGA actuelle peut etre trop petite

=================================================================
```

---

### 3. v_pga_stats.sql

**Objectif** : Analyse PGA detaillee avec top sessions gourmandes et risque ORA-04030

**Quand l'utiliser :**
- Diagnostiquer ORA-04030 (out of process memory)
- Identifier les sessions qui consomment le plus de PGA
- Verifier si les tris/jointures debordent sur disque (multipass)
- Utiliser V$PGA_TARGET_ADVICE pour dimensionner la PGA

**Execution :**
```sql
SQL> @v_pga_stats.sql
```

**Apercu du resultat :**
```
==================== PGA - ANALYSE DETAILLEE ====================

Indicateur PGA                           Valeur
---------------------------------------- ---------------
aggregate PGA target parameter              1.0 GB
aggregate PGA auto target                  656 MB
total PGA inuse                            295 MB
total PGA allocated                        399 MB
maximum PGA allocated                      518 MB
total freeable PGA memory                   68 MB
over allocation count                        0
cache hit percentage                       100 %

 Efficacite Workareas (tri, jointures, hash) :

Type execution               Nb Diagnostic
-------------------- ---------- ----------------------------------------
Total optimal           905,870 Executions 100% memoire (bon)
Total onepass (temp)          0 OK
Total multipass (lent)        0 OK (aucun multipass)

 Top 10 sessions par PGA (memoire privee) :

SID,Serial   Utilisateur     Programme                 PGA (MB)   Statut
------------ --------------- ------------------------- ---------- --------
142,34201    APP_PAIE        sqlplus.exe                     5.1  ACTIVE
87,12455     HR_ADMIN        JDBC Thin Client                3.3  ACTIVE
203,45678    BATCH_USER      python.exe                      3.2  INACTIVE
56,23190     APP_PAIE        sqlplus.exe                     2.6  ACTIVE
311,8921     COMPTA          JDBC Thin Client                2.3  INACTIVE

 Conseil Oracle (V$PGA_TARGET_ADVICE) :

PGA cible    Factor     Cache %    OverAlloc Conseil
------------ ---------- ----------    ------ -------------------------
     256 MB  0.25          99%        284    !! Risque ORA-04030
     512 MB  0.50         100%          0
       1.0 GB  1.00         100%          0    --> CONFIG ACTUELLE
       1.4 GB  1.40         100%          0
       2.0 GB  2.00         100%          0

 Actions :
 Over allocation count > 0   --> Augmenter PGA_AGGREGATE_TARGET
 Multipass executions > 0    --> PGA trop petite pour les tris/jointures
 Cache hit % < 80%           --> PGA sous-dimensionnee
 Top session > 500 MB        --> Verifier requete gourmande

=====================================================================
```

---

## Le concept cle : 2 zones memoire distinctes

| Element | Description | Analogie |
|---------|-------------|----------|
| **SGA** | Memoire PARTAGEE par tous les processus | Open space (partage) |
| **PGA** | Memoire PRIVEE par session utilisateur | Bureau personnel (prive) |
| **Buffer Cache** | Blocs de donnees en memoire (evite I/O disque) | Photocopieur partage |
| **Shared Pool** | Cache SQL + metadonnees + packages PL/SQL | Bibliotheque commune |
| **Redo Log Buffer** | Transactions avant ecriture disque (ACID) | Brouillon avant archivage |
| **Sort/Hash Area** | Zones PGA pour tris et jointures | Bureau de calcul personnel |

**La regle d'or :**
> SGA trop petite = Lent (I/O disque). PGA trop petite = Crash (ORA-04030).
> Toujours monitorer V$PGASTAT !

---

## Sizing recommande

| RAM Serveur | SGA_TARGET (50%) | PGA_AGGREGATE_TARGET (25%) | OS + Autres (25%) |
|-------------|------------------|----------------------------|--------------------|
| 16 GB | 8 GB | 4 GB | 4 GB |
| 32 GB | 16 GB | 8 GB | 8 GB |
| 64 GB | 32 GB | 16 GB | 16 GB |
| 128 GB | 64 GB | 32 GB | 32 GB |

> **JAMAIS depasser 80% de la RAM totale** (SGA + PGA). Laisser de la place a l'OS !

---

## Les 4 alertes memoire critiques

| Alerte | Cause | Gravite | Action |
|--------|-------|---------|--------|
| **ORA-04030** | PGA saturee | CRITIQUE | Augmenter PGA_AGGREGATE_TARGET |
| **ORA-04031** | Shared Pool sature | WARNING | Verifier curseurs, augmenter SGA |
| **checkpoint not complete** | Buffer Cache trop petit ou redo trop petits | WARNING | Augmenter SGA ou redo logs |
| **over allocation count > 0** | PGA depasse la cible | WARNING | Augmenter PGA ou reduire sessions |

---

## FAQ du module

**Q: ORA-04030 en production, que faire en urgence ?**
> 1. `SELECT name, value FROM v$pgastat WHERE name LIKE '%alloc%';` → Verifier saturation
> 2. `ALTER SYSTEM SET pga_aggregate_target=4G SCOPE=BOTH;` → Augmenter (effet immediat)
> 3. Identifier les sessions gourmandes avec `v_pga_stats.sql`

**Q: Comment savoir si ma SGA est bien dimensionnee ?**
> Execute `v_sga_detail.sql` → Si Buffer Cache Hit Ratio >= 95%, c'est bon.
> Si V$SGA_TARGET_ADVICE montre un gain avec plus de SGA, envisage d'augmenter.

**Q: Faut-il redemarrer pour changer SGA_TARGET ?**
> Oui dans la plupart des cas. `ALTER SYSTEM SET sga_target=4G SCOPE=BOTH;`
> modifie le SPFILE mais la SGA n'est reellement changee qu'au prochain STARTUP.
> PGA_AGGREGATE_TARGET est modifiable a chaud (effet immediat).

**Q: Combien de PGA par session est normal ?**
> En general 10-50 MB par session. Si < 5 MB, risque de debordement sur disque.
> Si une session depasse 500 MB, verifier la requete executee.

**Q: C'est quoi ASMM ?**
> Automatic Shared Memory Management (11g+). Tu definis SGA_TARGET et Oracle
> repartit automatiquement entre Buffer Cache, Shared Pool, etc.

---

## Vues Oracle utilisees

| Vue | Description |
|-----|-------------|
| `V$SGA` | Composants SGA et tailles |
| `V$SGASTAT` | Statistiques detaillees SGA (composants individuels) |
| `V$SGAINFO` | Information detaillee SGA (tailles max, redimensionnable) |
| `V$SGA_DYNAMIC_COMPONENTS` | Composants auto-tuning ASMM (resizes, min, max) |
| `V$SGA_TARGET_ADVICE` | Conseil Oracle : taille SGA optimale |
| `V$PGASTAT` | Statistiques PGA globales (allocation, over allocation) |
| `V$PGA_TARGET_ADVICE` | Conseil Oracle : taille PGA optimale |
| `V$SQL_WORKAREA_HISTOGRAM` | Workareas : optimal vs onepass vs multipass |
| `V$PROCESS` | Processus avec PGA par session (pga_used_mem) |
| `V$SESSION` | Sessions actives |
| `V$SYSSTAT` | Statistiques systeme (physical reads, consistent gets) |

---

## Pour aller plus loin

- **Theorie complete** : [Carrousel M1.4 sur LinkedIn](https://www.linkedin.com/posts/activity-7411303730580602880-i2D_)
- **Module precedent** : [M1.3 - Alert.log : Detecter les signaux faibles](../M1.3-Alert-Log/)
- **Prochain module** : M1.5 - Processus Background Oracle
- **Documentation Oracle** : [Memory Architecture](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/memory-architecture.html)

---

## A propos

**Auteur** : Omar SALL - DBA Oracle & Responsable Applications
**Experience** : 10+ ans en production critique (collectivites territoriales)
**Formation basee sur** : Formations ib Cegos (3000EUR+) + Livres Oracle 19c (ENI)

---

**#DBSentinelAcademy** | **#DBSA_M1_4** | Formation Oracle gratuite en francais
