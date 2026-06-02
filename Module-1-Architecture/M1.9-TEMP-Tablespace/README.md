# M1.9 - TEMP Tablespace

> **DBSentinel Academy** - Formation Oracle gratuite en francais
> *Par Omar SALL - DBA Oracle 10+ ans production*

---

## Prerequis

- **Acces** : SYSDBA, SELECT ANY DICTIONARY ou SELECT_CATALOG_ROLE
- **Compatibilite** : Oracle 12c, 18c, 19c, 21c, 23ai

> **Nouveau sur Oracle ?** Consulte le [Guide Demarrage Complet](../../README.md#guide-demarrage-complet) dans le README principal.

---

## Les 4 scripts de ce module

### 1. check_tempfiles.sql (RECOMMANDE pour commencer)

**Objectif** : Dashboard TEMP - allocation/utilisation par tempfile + alerte ORA-01652

**Ce que tu vas voir :**
- Detail de chaque tempfile (taille, utilise, libre, AUTOEXTEND)
- Resume par tablespace TEMP avec capacite max
- Verifications de configuration (TEMP par defaut, tempfiles sans AUTOEXTEND)

**Execution :**
```sql
SQL> @check_tempfiles.sql
```

**Apercu du resultat :**
```
==================== TEMP TABLESPACE - DIAGNOSTIC RAPIDE ====================

Tablespace           Tempfile                                 Alloue    Utilise   Libre     % Util  Max (Auto) % Max   Statut
-------------------- ---------------------------------------- --------- --------- --------- ------- ---------- ------- ------
TEMP                 /u01/oradata/ORCL/temp01.dbf                4,096     4,096         0  100.0%    16.0 GB  25.0%  OK
TEMP                 /u02/oradata/ORCL/temp02.dbf                4,096     3,520       576   85.9%    16.0 GB  21.5%  OK

 Resume par tablespace TEMP :

Tablespace            Nb Alloue    Utilise   Libre     % Util  Max (Auto) % Max
-------------------- --- --------- --------- --------- ------- ---------- -------
TEMP                   2     8,192     7,616       576   93.0%    32.0 GB   23.2%
```

---

### 2. v_temp_sessions.sql

**Objectif** : Identifier les sessions qui consomment le TEMP en temps reel + SQL_ID

**Quand l'utiliser :**
- Diagnostiquer un pic d'utilisation TEMP
- Cibler la session/requete qui sature le TEMP
- Comprendre la repartition par utilisateur et type d'operation

**Execution :**
```sql
SQL> @v_temp_sessions.sql
```

**Apercu du resultat :**
```
==================== TEMP - SESSIONS CONSOMMATRICES ====================

SID,Serial     Utilisateur     Programme              Tablespace         Type   Taille TEMP  SQL_ID
-------------- --------------- ---------------------- ------------------ ------ ------------ --------------
142,34201      APP_PAIE        sqlplus.exe            TEMP               SORT      485.0 MB  9k3hbz6rxk0p3
87,12455       HR_ADMIN        JDBC Thin Client       TEMP               HASH      312.0 MB  4xfgh7pmkw2qa
203,45678      BATCH_USER      python.exe             TEMP               SORT      245.0 MB  2nmkl9hxz3ert

 Repartition par type d'operation :

Type Operation   Nb Total       % TEMP   Description
--------------- --- ----------- --------- ----------------------------------------
SORT              4      940 MB    57.1%  ORDER BY, GROUP BY, DISTINCT
HASH              3      595 MB    36.2%  Hash Join, GROUP BY (HASH)
DATA              1      156 MB     9.5%  Tables temporaires (GTT)
```

---

### 3. v_workarea_efficiency.sql

**Objectif** : Verifier l'efficacite des tris (optimal/onepass/multipass)

**Quand l'utiliser :**
- Detecter les debordements PGA -> TEMP (onepass/multipass)
- Diagnostiquer PGA sous-dimensionnee
- Justifier une augmentation de PGA_AGGREGATE_TARGET

**Execution :**
```sql
SQL> @v_workarea_efficiency.sql
```

**Apercu du resultat :**
```
==================== WORKAREA - EFFICACITE TRIS / HASH ====================

Metrique                                 Valeur            Diagnostic
---------------------------------------- ----------------- ----------------------------------------
Total executions optimal (en memoire)             905,870  OK : > 95% en memoire
Total executions onepass (overflow TEMP)              892  INFO : 0.1% overflow disque
Total executions multipass (LENT)                       0  OK : aucun multipass

 Workareas actives en ce moment :

 SID Operation            Policy       Attendu      Actif        Passes
---- -------------------- ------------ ------------ ------------ ------
 142 SORT (v2)            AUTO              512 MB       485 MB      1
  87 HASH-JOIN            AUTO              384 MB       312 MB      1
```

---

### 4. v_temp_sizing.sql

**Objectif** : Calculer le dimensionnement TEMP recommande (formule PGA x DOP)

**Quand l'utiliser :**
- Valider la taille TEMP avant mise en production
- Justifier une extension TEMP aupres du management
- Anticiper les besoins TEMP pour traitements paralleles

**Execution :**
```sql
SQL> @v_temp_sizing.sql
```

**Apercu du resultat :**
```
==================== TEMP - SIZING ET RECOMMANDATIONS ====================

Parametre                                Valeur        Impact sur TEMP
---------------------------------------- ------------- ----------------------------------------
PGA_AGGREGATE_TARGET                          2.0 GB   Memoire PGA disponible pour tris
PARALLEL_MAX_SERVERS                              80   Multiplicateur potentiel TEMP par session
WORKAREA_SIZE_POLICY                          AUTO     AUTO = Oracle gere

 Comparaison TEMP actuel vs recommande :

Element                                  Valeur            Recommandation
---------------------------------------- ----------------- ----------------------------------------
TEMP actuellement alloue                          8.0 GB   -
TEMP max (avec AUTOEXTEND)                       32.0 GB   -
TEMP recommande minimum (2 x PGA)                 4.0 GB   OK : capacite max suffisante
TEMP recommande optimal (3 x PGA)                 6.0 GB   OK : optimal
TEMP avec parallelism (3 x PGA x DOP/8)          60.0 GB   Si traitements paralleles intensifs
```

---

## Le concept cle : TEMP = quand la PGA deborde

| Operation Oracle | TEMP utilise quand ? |
|------------------|---------------------|
| **ORDER BY** | Si tri ne tient pas en PGA (SORT_AREA) |
| **GROUP BY** | Si agregation depasse HASH_AREA |
| **DISTINCT** | Si dedoublonnage depasse PGA |
| **Hash Join** | Si build table > HASH_AREA_SIZE |
| **Sort Merge Join** | Si tri preliminaire > SORT_AREA_SIZE |
| **CREATE INDEX** | Phase de tri du futur index |
| **Tables temporaires (GTT)** | Stockage GLOBAL TEMPORARY TABLE |
| **CTE / WITH clause** | Si materialisation forcee |

**La regle d'or :**
> PGA petite + workload important = overflow TEMP systematique = ralentissements + risque ORA-01652.
> TEMP doit etre dimensionne pour absorber les pics : 2-3x la PGA_AGGREGATE_TARGET en regle generale.

---

## Les 5 erreurs critiques liees au TEMP

| Erreur | Cause | Gravite | Action |
|--------|-------|---------|--------|
| **ORA-01652** | TEMP plein (pas d'extension) | CRITIQUE | Ajouter tempfile ou activer AUTOEXTEND |
| **AUTOEXTEND OFF** | Config par defaut oubliee | CRITIQUE | `ALTER DATABASE TEMPFILE ... AUTOEXTEND ON` |
| **Multipass > 0** | PGA tres sous-dimensionnee | CRITIQUE | Augmenter PGA_AGGREGATE_TARGET |
| **Tempfile unique** | Pas de repartition I/O | WARNING | Ajouter 2eme tempfile sur autre disque |
| **TEMP non MAX'd** | MAXSIZE non specifie | WARNING | Definir MAXSIZE pour eviter remplissage disque |

---

## FAQ du module

**Q: ORA-01652 en production, que faire en urgence ?**
> 1. `@check_tempfiles.sql` -> Verifier % utilise et AUTOEXTEND
> 2. `@v_temp_sessions.sql` -> Identifier la session bloquante
> 3. Killer la session si necessaire : `ALTER SYSTEM KILL SESSION 'sid,serial#' IMMEDIATE;`
> 4. Etendre TEMP : `ALTER DATABASE TEMPFILE '/u01/oradata/ORCL/temp01.dbf' AUTOEXTEND ON MAXSIZE 32G;`
> 5. Ou ajouter tempfile : `ALTER TABLESPACE TEMP ADD TEMPFILE '/u02/oradata/ORCL/temp02.dbf' SIZE 4G AUTOEXTEND ON;`

**Q: Combien de tempfiles ? Un seul ou plusieurs ?**
> Plusieurs si activite TEMP intensive ou paralellism. 2-4 tempfiles sur disques differents permet une meilleure repartition I/O.
> Pour des bases < 100 GB : 1 seul tempfile suffit generalement.

**Q: TEMP est plein mais aucune session ne le libere ?**
> Verifier les sessions zombies avec `@v_temp_sessions.sql`. Si une session est marquee INACTIVE depuis longtemps avec un segment TEMP, la killer.

**Q: Faut-il backupper le TEMP ?**
> Non. Le TEMP est non-journalise et recree au demarrage. RMAN ne backuppe pas les tempfiles. En cas de perte : `ALTER TABLESPACE TEMP ADD TEMPFILE ...`

**Q: Difference entre V$SORT_USAGE et V$TEMPSEG_USAGE ?**
> V$SORT_USAGE = ancien nom (avant 11g). V$TEMPSEG_USAGE = nouveau nom (11g+). Ils referencent la meme vue interne. Utiliser V$TEMPSEG_USAGE en 12c+.

---

## Vues Oracle utilisees

| Vue | Description |
|-----|-------------|
| `DBA_TEMP_FILES` | Inventaire tempfiles (taille, autoextend, maxbytes) |
| `V$TEMP_SPACE_HEADER` | Espace utilise/libre par tempfile en temps reel |
| `V$TEMPSEG_USAGE` | Sessions actives utilisant TEMP (segments en cours) |
| `V$SESSION` | Identification utilisateur, programme, SQL_ID |
| `V$SQL_WORKAREA_HISTOGRAM` | Statistiques workarea agregees (optimal/onepass/multipass) |
| `V$SQL_WORKAREA_ACTIVE` | Workareas en cours d'execution (temps reel) |
| `V$PGASTAT` | Statistiques globales PGA |
| `V$PARAMETER` | PGA_AGGREGATE_TARGET, PARALLEL_MAX_SERVERS, WORKAREA_SIZE_POLICY |
| `DATABASE_PROPERTIES` | Tablespace TEMP par defaut |
| `DBA_TABLESPACES` | Type des tablespaces (CONTENTS = TEMPORARY) |

---

## Pour aller plus loin

- **Theorie complete** : [Carrousel M1.9 sur LinkedIn](https://www.linkedin.com/posts/activity-7423987331981815808-o28L)
- **Module precedent** : [M1.8 - Control Files](../M1.8-Control-Files/)
- **Prochain module** : M1.10 - UNDO Tablespace et Transactions
- **Documentation Oracle** : [Managing Temporary Tablespaces](https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/managing-tablespaces.html#GUID-22B7C418-43E6-4D11-A881-DD0CABD22E5E)

---

## A propos

**Auteur** : Omar SALL - DBA Oracle & Responsable Applications
**Experience** : 10+ ans en production critique (collectivites territoriales)
**Formation basee sur** : Formations ib Cegos (3000EUR+) + Livres Oracle 19c (ENI)

---

**#DBSentinelAcademy** | **#DBSA_M1_9** | Formation Oracle gratuite en francais
