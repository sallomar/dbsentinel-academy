# M1.12 - Architecture Oracle, vue d'ensemble

> **DBSentinel Academy** - Formation Oracle gratuite en francais
> *Par Omar SALL - DBA Oracle 10+ ans production*

---

## Prerequis

- **Acces** : SYSDBA, SELECT ANY DICTIONARY ou SELECT_CATALOG_ROLE
- **Compatibilite** : Oracle 12c, 18c, 19c, 21c, 23ai
- **Aucune option Oracle requise** : ces scripts n'interrogent ni `DBA_HIST_*`,
  ni `V$ACTIVE_SESSION_HISTORY`, ni les vues ADDM. Ils fonctionnent sur une base
  sans Diagnostics Pack ni Tuning Pack.

> **Nouveau sur Oracle ?** Consulte le [Guide Demarrage Complet](../../README.md#guide-demarrage-complet) dans le README principal.

### Portee : RAC, CDB, et duree d'execution

Trois points a connaitre avant de lancer ces scripts sur une base de production.

| Contexte | Ce qui change |
|----------|---------------|
| **RAC** | Les vues `V$` sont **locales a l'instance**. Memoire, processus, sessions et alert.log ne decrivent que le noeud sur lequel tu es connecte : relancer sur chaque noeud. Fichiers, tablespaces et schemas sont, eux, a l'echelle de la base. `v_sessions_locks.sql` detecte les blocages inter-noeuds et les compte a part, sans jamais les attribuer a une session locale portant le meme SID. |
| **CDB / PDB** | Le conteneur courant est affiche dans la carte d'identite. Depuis `CDB$ROOT`, les piliers 3 et 4 ne couvrent **que la racine** : pour auditer une PDB, `ALTER SESSION SET CONTAINER = ma_pdb;` avant de lancer le script. Les sauvegardes RMAN ne sont visibles que depuis `CDB$ROOT`, et le script le signale au lieu d'annoncer une absence de sauvegarde. |
| **Duree** | `V$DIAG_ALERT_EXT` reparse l'integralite des fichiers XML de l'ADR : sur une base dont l'ADR n'a jamais ete purge, `daily_healthcheck.sql` peut prendre plusieurs minutes. `DBA_FREE_SPACE` est egalement lente sur une base tres fragmentee. Ce sont des `SELECT`, sans effet de bord, mais ne les lance pas en pleine fenetre de production critique la premiere fois. |

---

## Ce module est different des onze precedents

Les modules M1.1 a M1.11 examinent **un composant a la fois**, en profondeur.
Celui-ci fait l'inverse : il regarde **les interactions**, la ou les incidents
reels se produisent. Un tablespace plein ne casse rien tout seul ; c'est quand
il rencontre un batch qui ne commite pas, un jour ou la sauvegarde a echoue,
que la journee devient longue.

Les quatre scripts ne remplacent donc aucun script des modules precedents.
Ils disent **ou regarder**. Les autres disent **quoi corriger**, et les lignes
d'alerte renvoient au module concerne quand un script dedie existe.

---

## Les 4 scripts de ce module

### 1. check_architecture.sql (RECOMMANDE pour commencer)

**Objectif** : Voir les 4 piliers de l'architecture sur une seule page

**Ce que tu vas voir :**
- Carte d'identite : nom, conteneur, statut, mode d'ouverture, archivage, duree de fonctionnement
- Pilier 1, l'instance : SGA et sa part libre, PGA face a sa cible, processus critiques, sessions
- Pilier 2, la database : les 5 types de fichiers, avec leur volume et leur etat
- Pilier 3, les tablespaces structurants (SYSTEM, SYSAUX, UNDO, TEMP) plus tout
  tablespace applicatif dont le **plafond** se rapproche
- Pilier 4, l'organisation logique : schemas, objets, espace, segments mal places

**Execution :**
```sql
SQL> @check_architecture.sql
```

**Apercu du resultat :**
```
=============== ARCHITECTURE ORACLE - LES 4 PILIERS ===============

Base         Instance         Conteneur        Statut       Ouverture              Archivage         Version      Demarree depuis
------------ ---------------- ---------------- ------------ ---------------------- ----------------- ------------ ----------------
ORCL         ORCL             Non-CDB          OPEN         READ WRITE             ARCHIVELOG        19.0.0.0.0   18 j 2 h

 PILIER 1 - INSTANCE : memoire et processus (perdus au SHUTDOWN)

Composant                  Mesure         Detail
-------------------------- -------------- ----------------------------------------------------------
SGA (memoire partagee)           2,048 MB ASMM actif, entierement distribuee aux pools
PGA (memoire privee)               312 MB Cible 512 MB, atteinte a 61%
Processus background                   42 PMON, SMON, LGWR, CKPT, DBW0 : tous actifs
Sessions utilisateur                   87 14 active(s), 129 au total avec les background
Pic de sessions atteint               214 Sur une limite de 300 (parametre SESSIONS)

 PILIER 3 - TABLESPACES : SYSTEM, SYSAUX, UNDO, TEMP et les tendus

Tablespace           Nature      Occupe        Alloue        % All  Plafond       % Max  Verdict
-------------------- ----------- ------------- ------------- ------ ------------- ------ ----------------------------------------------
SYSTEM               SYSTEM             934 MB      1,024 MB  91.2%     32,768 MB   2.9% S'etendra bientot : verifier l'espace disque
SYSAUX               SYSAUX           1,772 MB      2,048 MB  86.5%      4,096 MB  43.3% Surveiller : extension prochaine
UNDOTBS1             UNDO             1,692 MB      2,048 MB  82.6%     32,768 MB   5.2% Extents expires recycles en interne (M1.10)
TEMP                 TEMPORAIRE         214 MB      2,048 MB  10.4%          FIXE  10.4% Extents reutilisables deduits        (M1.9)
APP_DATA             APPLICATIF       1,908 MB      2,048 MB  93.2%          FIXE  93.2% !! Activer AUTOEXTEND ou un fichier  (M1.6)
APP_ARCHIVE          APPLICATIF      29,847 MB     30,720 MB  97.2%     32,768 MB  91.1% !! Ajouter un datafile : MAXSIZE au max
APP_INDEX            APPLICATIF       1,204 MB      1,280 MB  94.1%      1,536 MB  78.4% Surveiller : le plafond se rapproche
```

**Les deux pourcentages ne disent pas la meme chose**, et il faut les lire ensemble :

| Colonne | Question a laquelle elle repond |
|---------|--------------------------------|
| `% All` | Oracle va-t-il devoir **etendre** le fichier bientot ? Si oui, l'espace disque devient la vraie limite |
| `% Max` | Lui reste-t-il le **droit** de le faire ? C'est le seul mur certain cote Oracle |

Les trois tablespaces applicatifs de l'exemple ont des `% All` voisins (93 a 97 %)
pour trois situations completement differentes : `APP_INDEX` s'etendra tout seul
jusqu'a son `MAXSIZE`, `APP_DATA` n'a pas d'AUTOEXTEND et le prochain `INSERT`
sans extent disponible levera un `ORA-01653`, `APP_ARCHIVE` a de l'AUTOEXTEND mais
touche la limite physique de ses datafiles. Un seul pourcentage n'aurait pas permis
de les distinguer.

> **`MAXSIZE UNLIMITED` ne veut pas dire illimite.** Un datafile *smallfile*
> s'arrete a 4 194 302 blocs, soit **32 GB en blocs de 8 K** (16 GB en 4 K,
> 64 GB en 16 K), et c'est exactement la valeur qu'Oracle inscrit dans
> `DBA_DATA_FILES.MAXBYTES` quand on declare `UNLIMITED`. Rien dans le
> dictionnaire ne dit ensuite si le DBA a ecrit `UNLIMITED` ou un `MAXSIZE`
> chiffre : seul le nombre d'octets subsiste. C'est pour cela que ce script
> affiche toujours le plafond **chiffre** plutot qu'une mention `ILLIMITE` :
> sur l'exemple, `APP_ARCHIVE` est a 91 % de ce plafond avec moins de 3 GB de
> marge, ce qu'une etiquette `ILLIMITE` aurait purement masque.

Quand ce plafond physique est atteint, relever `MAXSIZE` ne sert a rien. Il faut
**ajouter un datafile** — sauf sur un tablespace `BIGFILE`, qui n'en accepte
qu'un seul (`ORA-32771`) et se redimensionne a la place. Le script distingue les
deux cas et n'affiche jamais un conseil inapplicable. Passer un tablespace
existant en `BIGFILE` n'est pas une conversion en place : il faut creer un
tablespace bigfile et y deplacer les segments.

> **Pourquoi ce script n'utilise pas `DBA_TABLESPACE_USAGE_METRICS`.** C'est le
> raccourci habituel pour ce calcul, mais elle rapporte toute l'occupation a
> cette limite physique de 32 GB des qu'un fichier est en `MAXSIZE UNLIMITED` :
> un SYSTEM rempli a 91 % de son espace alloue y apparait a **2,9 %**, verdict
> `OK`. Le script recalcule donc depuis `DBA_DATA_FILES`, `DBA_FREE_SPACE` et
> `DBA_TEMP_FREE_SPACE`.

---

### 2. daily_healthcheck.sql

**Objectif** : Les 5 controles du matin en une seule execution

**Quand l'utiliser :**
- Chaque matin, avant l'arrivee des utilisateurs
- Au retour de conges, pour savoir ce qui s'est passe pendant l'absence
- A la prise en main d'une base inconnue (audit, remplacement, astreinte)

**Execution :**
```sql
SQL> @daily_healthcheck.sql
```

**Apercu du resultat :**
```
================ CHECK-UP QUOTIDIEN - LES 5 CONTROLES ================

Controle                   Resultat                                                 Si alerte, lancer
-------------------------- -------------------------------------------------------- --------------------------------
1. Alert.log (24h)         !! 7 erreur(s) ORA - voir le detail plus bas             @check_alertlog.sql    (M1.3)
2. Espace tablespaces      !! APP_DATA a 93.2% du plafond                           @check_tablespaces.sql (M1.6)
3. Zone d'archivage        OK : FRA a 62.4% (espace recuperable deduit)             @v_fra_usage.sql       (M1.7)
4. Sessions bloquees       !! 3 bloquee(s), la plus ancienne depuis 38 min          @v_sessions_locks.sql  (M1.12)
5. Derniere sauvegarde     OK : 20/08/2026 02:14 (il y a 6.0 h)                     RMAN> LIST BACKUP SUMMARY

 Detail des erreurs ORA des 24 dernieres heures (une ligne par code) :

Code              Nb Premiere          Derniere          Signification                                Gravite
------------ ------- ----------------- ----------------- -------------------------------------------- ----------------------
ORA-01555          4 19/08 22:41:08    20/08 03:17:55    UNDO recycle trop vite                       A analyser
ORA-00060          2 19/08 14:02:37    19/08 16:48:12    Deadlock : deux sessions s'attendent         A analyser
ORA-01652          1 20/08 03:22:41    20/08 03:22:41    Segment temporaire : tablespace sature       !! Production impactee
```

> **Une ligne par code d'erreur, jamais une ligne par occurrence.** Un `ORA-01555`
> survenu 400 fois dans la nuit reste une seule ligne, avec son compteur et ses
> horodatages extremes. C'est ce qui rend la sortie lisible un lundi matin.

**Un check quotidien doit rester credible**, sinon plus personne ne l'ouvre. Deux
precautions y contribuent, et meritent d'etre connues :

- **L'alert.log ecrit les codes sans zeros de tete** : `ORA-1652`, pas `ORA-01652`.
  Une expression reguliere exigeant cinq chiffres ignorerait silencieusement les
  erreurs d'espace les plus courantes. Le script accepte les deux formes et les
  compte ensemble.
- **Les messages benins sont exclus** : `ORA-609` (deconnexion brutale d'un client),
  `ORA-279`/`280`/`312` (messages normaux de redo), et les codes Data Guard
  apparaissent en permanence sur une base saine. Sans exclusion, le controle serait
  rouge tous les matins.

**A savoir sur le controle 5** : la date de sauvegarde est lue dans le control file
via `V$RMAN_BACKUP_JOB_DETAILS`. `CONTROL_FILE_RECORD_KEEP_TIME` (7 jours par
defaut) definit la duree **minimale** pendant laquelle Oracle s'interdit de
recycler l'enregistrement — au-dela, il peut avoir disparu. Seul le statut
`COMPLETED` compte comme un succes : `COMPLETED WITH ERRORS` est un echec partiel,
et le script le signale comme tel plutot que de l'afficher en vert. Seules les
sauvegardes de donnees sont retenues : un backup d'archivelogs seul ne rend pas
la base restaurable.

---

### 3. v_startup_readiness.sql

**Objectif** : Si tu redemarrais maintenant, ou est-ce que ca casserait ?

> **Ce script s'execute sur une base OUVERTE.** Il ne remplace pas le diagnostic
> d'une base qui refuse de demarrer : dans ce cas seules repondent les vues de la
> phase deja atteinte — `V$PARAMETER` et `V$SGA` des `NOMOUNT`, `V$DATAFILE` et
> `V$LOG` une fois la base montee — et l'alert.log fait foi.
> C'est un audit **preventif**, a lancer **avant** un arret planifie.

**Quand l'utiliser :**
- Avant un arret pour maintenance systeme, patch ou demenagement de serveur
- Apres une intervention d'infrastructure (stockage, sauvegarde, reseau)
- Une fois par mois, pour verifier que rien n'a derive silencieusement

**Execution :**
```sql
SQL> @v_startup_readiness.sql
```

**Apercu du resultat :**
```
============ REDEMARRAGE : CE QUI TIENDRAIT, CE QUI CASSERAIT ============

 PHASE 1 - NOMOUNT : lecture des parametres et allocation de la SGA

Point de controle                            Etat
-------------------------------------------- ----------------------------------------------------------------------
Fichier de parametres utilise                OK : SPFILE spfileORCL.ora
Parametres actifs mais absents du SPFILE     !! 2 parametre(s) perdu(s) au STARTUP : log_archive_dest_2
Dimensionnement memoire declare              SGA 2,048 MB + PGA cible 512 MB a reserver en RAM au STARTUP

 PHASE 3 - OPEN : ouverture des datafiles et des redo logs

Point de controle                            Etat
-------------------------------------------- ----------------------------------------------------------------------
Datafiles accessibles (en-tetes)             OK : 14 en-tetes lus sans erreur
Datafiles necessitant un recovery            OK : aucun fichier en RECOVER
Datafiles restes en mode sauvegarde          OK : aucun BEGIN BACKUP en cours
Membres de redo logs indisponibles           OK : tous les membres sont lisibles
Groupes de redo a membre unique              OK : chaque groupe est multiplexe
Tempfiles declares                           OK : 1 tempfile(s), l'OPEN n'en depend pas
```

**Le controle le plus utile de ce script** est celui de la phase NOMOUNT :
*parametres actifs mais absents du SPFILE*. Un `ALTER SYSTEM ... SCOPE=MEMORY`
fonctionne parfaitement jusqu'au prochain `SHUTDOWN`, puis disparait sans un mot.
La base redemarre avec l'ancienne valeur du SPFILE, souvent des semaines plus tard,
quand plus personne ne fait le lien entre la lenteur constatee et le tuning oublie.

La comparaison porte sur `DISPLAY_VALUE` des deux cotes, et non sur `VALUE` :
`V$PARAMETER` stocke `2147483648` la ou le SPFILE garde `2G`. Comparer les valeurs
brutes declarerait « perdu » un parametre parfaitement persistant.

---

### 4. v_sessions_locks.sql

**Objectif** : Qui bloque qui, et depuis combien de temps

**Quand l'utiliser :**
- Un utilisateur signale que "l'application est figee" alors que la base va bien
- Le controle 4 du health check a leve une alerte
- Avant de tuer une session : comprendre ce qu'on est en train de tuer

**Execution :**
```sql
SQL> @v_sessions_locks.sql
```

**Apercu du resultat :**
```
 Chaines de blocage : une ligne par session bloquante

Session bloquante          Provenance               Bloq. Attente max  Objet en conflit       Verdict
-------------------------- ------------------------ ----- ------------ ---------------------- --------------------------------------------
412 - BATCH_USER           batch_cloture.sh             3       38 min BULLETIN_PAIE          !! Inactive depuis 2.3 h : COMMIT oublie

 Requetes actives depuis plus de 10 minutes (10 premieres) :

SID,Serial     Compte             Origine                    En cours     Attend sur                     Debut de la requete
-------------- ------------------ -------------------------- ------------ ------------------------------ ----------------------------------------
1892,44201     APP_PAIE           rapport_mensuel.sql              47 min db file sequential read        SELECT b.matricule, SUM(b.montant) FROM
2104,18337     HR_ADMIN           JDBC Thin Client                 38 min enq: TX - row lock contention  UPDATE agents SET service = :1 WHERE mat
731,50912      BATCH_USER         batch_cloture.sh                 18 min direct path read temp          SELECT * FROM ( SELECT a.*, ROW_NUMBER()
```

> **Une ligne par session bloquante, jamais une ligne par verrou.** Une session qui
> bloque 40 autres tient sur une seule ligne, avec le compteur `Bloq.` et l'attente
> la plus longue. Chaque section affiche une ligne `Aucune...` quand elle ne trouve
> rien : une section vide est un resultat, pas un doute sur l'execution du script.

**Le verdict repose sur le statut du bloquant, pas sur la duree.** C'est le point
important : un bloquant `ACTIVE` travaille, il finira. Un bloquant `INACTIVE`
detient des verrous sans plus rien faire, et ne les rendra jamais tout seul.

**En RAC**, `V$SESSION` est locale. Le script ne detaille que les chaines dont le
bloqueur est sur l'instance courante, et compte les blocages inter-noeuds a part.
C'est une precaution qui evite le pire : sans elle, un SID distant correspondrait
a une session locale sans aucun rapport, et le script designerait un innocent a tuer.

---

## Le concept cle : la chaine, pas les maillons

| Question | Le module qui repond | Ce que M1.12 ajoute |
|----------|----------------------|---------------------|
| Mon tablespace est-il plein ? | M1.6 | Est-il plein **le jour ou** la sauvegarde a echoue ? |
| Mon UNDO est-il bien dimensionne ? | M1.10 | Le batch qui le remplit **bloque-t-il** d'autres sessions ? |
| Mes control files sont-ils multiplexes ? | M1.8 | La base **redemarrerait**-elle ce soir ? |
| Qui possede quoi ? | M1.11 | Ces objets sont-ils **la ou ils devraient etre** ? |

Un incident de production est presque toujours une **conjonction**. C'est pour
cela qu'un DBA experimente ouvre d'abord une vue large, puis descend : l'inverse
fait perdre des heures a examiner en detail un composant qui n'y est pour rien.

---

## Les pieges classiques de la vue d'ensemble

| Erreur | Ce qui se passe reellement | Action |
|--------|----------------------------|--------|
| **Lire un seul pourcentage d'occupation** | A 93%, un tablespace en AUTOEXTEND grandira seul quand un tablespace fixe levera un `ORA-01653`. Le meme chiffre, deux urgences opposees | Lire `% All` **et** la colonne `Plafond` avant de conclure |
| **Croire `MAXSIZE UNLIMITED` sans limite** | Le datafile s'arrete a 32 GB (blocs de 8 K). Un tablespace a 29 GB n'a plus que 3 GB de marge, sans qu'aucune alerte ne l'annonce | Lire le plafond chiffre, et prevoir un datafile de plus ou un tablespace `BIGFILE` |
| **Alerter sur un UNDO ou un TEMP a 80%** | Leurs extents liberes restent alloues pour etre reutilises : un taux eleve y est le regime normal, jusqu'a 95% ou la marge disparait vraiment | Les traiter avec M1.10 et M1.9, jamais avec les seuils d'un tablespace permanent |
| **Lire le nombre de sessions sans regarder leur type** | `V$RESOURCE_LIMIT` compte une session par processus background : 129 sessions pour 87 connexions applicatives | Filtrer `V$SESSION.TYPE = 'USER'` pour les connexions, garder le total pour le parametre `SESSIONS` |
| **Tuer la session bloquante par reflexe** | Le `ROLLBACK` d'une grosse transaction peut prendre autant de temps que la transaction elle-meme, parfois davantage. Les verrous ne tombent qu'a la fin | Lire le verdict : un bloquant `ACTIVE` se laisse finir, un bloquant `INACTIVE` se traite |
| **Croire qu'un `ALTER SYSTEM` est permanent** | Sans `SCOPE=BOTH` ni SPFILE, la valeur tient jusqu'au `SHUTDOWN` puis disparait, et la base repart avec l'ancienne | `@v_startup_readiness.sql`, phase NOMOUNT |
| **Verifier la sauvegarde uniquement quand on en a besoin** | On decouvre qu'elle echoue depuis trois semaines le jour de la restauration | Controle 5 du health check, chaque matin |
| **Oublier un `BEGIN BACKUP`** | Le `SHUTDOWN` planifie refuse alors de s'executer (`ORA-01149`) ; apres un arret brutal, c'est l'ouverture qui echoue (`ORA-01113`) | `@v_startup_readiness.sql`, phase OPEN |

---

## FAQ du module

**Q: Pourquoi un douzieme module alors que tout a deja ete vu ?**
> Parce que connaitre chaque composant ne dit rien de leurs interactions, et que
> les incidents naissent des interactions. Ce module ne rajoute pas de theorie :
> il donne les quatre scripts qu'on lance quand on ne sait pas encore ou chercher.

**Q: Dans quel ordre lancer ces scripts ?**
> `@daily_healthcheck.sql` chaque matin. S'il leve une alerte, il indique lui-meme
> le script a lancer ensuite. `@check_architecture.sql` a la prise en main d'une
> base ou apres un changement d'infrastructure. `@v_startup_readiness.sql` avant
> tout arret planifie. `@v_sessions_locks.sql` quand quelque chose est "fige".

**Q: Le health check dit OK, la base est-elle saine ?**
> Il dit que les cinq points les plus souvent en cause vont bien. Ce n'est pas
> un audit complet : il ne regarde ni les performances, ni la securite, ni la
> coherence applicative. C'est un controle de 30 secondes, pas une expertise.

**Q: Pourquoi deux colonnes de pourcentage sur les tablespaces ?**
> Parce qu'aucune des deux ne suffit seule. `% All` (occupe / alloue) dit si Oracle
> va bientot devoir etendre le fichier ; `% Max` (occupe / plafond) dit s'il en a
> encore le droit. Un tablespace a 98% de son espace alloue mais a 30% de son
> `MAXSIZE` n'a aucun probleme. Le meme 98% sans `AUTOEXTEND` est un `ORA-01653`
> imminent. La colonne `Plafond` indique laquelle des deux lire.
> Voir aussi [M1.6](../M1.6-Tablespaces-Datafiles/).

**Q: Mes datafiles sont en `MAXSIZE UNLIMITED`, pourquoi le script affiche un plafond de 32 GB ?**
> Parce que c'est le vrai plafond. `UNLIMITED` ne cree pas un espace infini : il
> demande a Oracle d'aller jusqu'a la limite physique du datafile, soit
> 4 194 302 blocs — 32 GB en blocs de 8 K, 16 GB en 4 K, 64 GB en 16 K. Un
> tablespace de 29 GB en `UNLIMITED` n'a donc que 3 GB de marge avant `ORA-01653`.
> Le seul recours a ce moment-la est d'ajouter un datafile, ou de creer un
> tablespace `BIGFILE` et d'y deplacer les segments — un bigfile monte a 32 To
> avec le meme bloc de 8 K. Attention : il n'existe **aucune conversion en place**
> d'un tablespace smallfile vers bigfile.

**Q: Un `% All` eleve avec AUTOEXTEND, faut-il s'en inquieter ?**
> Pas en soi : c'est le regime normal. Un tablespace en AUTOEXTEND remplit son
> espace alloue puis demande un peu plus au systeme de fichiers, en boucle. Le
> risque n'apparait que si le disque est plein, ce qu'aucune vue Oracle ne sait
> voir. C'est pourquoi `daily_healthcheck.sql` n'alerte que sur `% Max` : alerter
> chaque matin sur des tablespaces qui respirent normalement ferait ignorer les
> vraies alertes au bout d'une semaine.

**Q: Pourquoi UNDO et TEMP sont-ils juges differemment des autres tablespaces ?**
> Parce qu'un taux d'occupation eleve y est le **regime normal**. Oracle ne rend
> pas les extents au tablespace apres usage : il les conserve alloues pour les
> reutiliser, ce qui evite un cout d'allocation a chaque requete. Un UNDO ou un
> TEMP a 80 % n'annonce donc aucun incident, et le faire remonter en rouge chaque
> matin ferait perdre toute credibilite au controle. Ils ne sont pour autant pas
> exemptes de tout seuil : **au-dela de 95 % de leur plafond**, les extents
> reutilisables ne suffisent plus et le script alerte — c'est le terrain de
> l'`ORA-01652` pour TEMP et de l'`ORA-30036` pour UNDO.
> Pour TEMP, le script lit `DBA_TEMP_FREE_SPACE`, seule vue qui deduit ces extents
> reutilisables : `V$TEMP_SPACE_HEADER.BYTES_USED` est un high water mark qui ne
> redescend jamais et afficherait un TEMP parfaitement sain a 100 %. Le
> dimensionnement reel se traite avec
> [M1.10](../M1.10-UNDO-Tablespace-Transactions/) et
> [M1.9](../M1.9-TEMP-Tablespace/).

**Q: Pourquoi deux lignes de sessions, avec des chiffres si differents ?**
> Parce qu'elles ne comptent pas la meme chose. `Sessions utilisateur` ne retient
> que `V$SESSION.TYPE = 'USER'` : ce sont les connexions applicatives. Le total
> indique a cote provient de `V$RESOURCE_LIMIT`, qui compte **aussi une session
> par processus background**. Sur une base peu sollicitee, l'ecart est
> spectaculaire : deux connexions applicatives pour plus de cinquante sessions au
> total. C'est ce second chiffre, et lui seul, qui se compare au parametre
> `SESSIONS`.

**Q: Pourquoi une session INACTIVE peut-elle bloquer les autres ?**
> Parce que `INACTIVE` decrit la session, pas sa transaction. Une session qui a
> fait un `UPDATE` sans `COMMIT` puis n'a plus rien envoye est `INACTIVE` : elle
> n'execute rien, mais elle detient toujours ses verrous. Elle les gardera jusqu'au
> `COMMIT`, au `ROLLBACK` ou a la deconnexion. C'est le scenario le plus frequent
> en production, et il n'a rien d'anormal du point de vue d'Oracle.

**Q: `V$RMAN_BACKUP_JOB_DETAILS` est-elle sous licence ?**
> Non. Elle lit le control file, comme toutes les vues RMAN. Aucun script de ce
> depot n'interroge de vue relevant du Diagnostics Pack ou du Tuning Pack :
> ni `DBA_HIST_*`, ni `V$ACTIVE_SESSION_HISTORY`, ni les vues ADDM.

**Q: Puis-je automatiser ces scripts en tache planifiee ?**
> Oui, ce sont des `SELECT` sans effet de bord. Rediriger la sortie vers un fichier
> horodate et ne notifier que si la sortie contient `!!` donne un premier systeme
> d'alerte tres correct, sans aucun outil supplementaire. Verifie d'abord la duree
> d'execution sur ta base : voir la section *Portee* en haut de ce document.

---

## Vues Oracle utilisees

| Vue | Description |
|-----|-------------|
| `V$INSTANCE` | Identite et statut de l'instance, date de demarrage, version |
| `V$DATABASE` | Nom, mode d'ouverture, mode d'archivage, role |
| `V$SGA` / `V$SGA_DYNAMIC_FREE_MEMORY` | Memoire partagee allouee, et part pas encore attribuee a un pool |
| `V$PGASTAT` | Memoire privee reellement allouee aux sessions |
| `V$BGPROCESS` | Processus background demarres (`PADDR <> '00'`) |
| `V$RESOURCE_LIMIT` | Sessions courantes, pic depuis le demarrage et limite configuree |
| `V$SESSION` | Sessions, statut, inactivite, chaines de blocage (`BLOCKING_SESSION`, `BLOCKING_INSTANCE`) |
| `V$SQLAREA` | Texte de la requete en cours d'execution, par `SQL_ID` |
| `V$DATAFILE` / `V$TEMPFILE` | Fichiers de donnees et de tri, taille et statut |
| `V$DATAFILE_HEADER` | En-tetes lus au demarrage : detecte un fichier inaccessible |
| `V$CONTROLFILE` | Copies du control file, taille, emplacements |
| `V$LOG` / `V$LOGFILE` | Groupes et membres de redo logs, multiplexage, membres invalides |
| `V$ARCHIVED_LOG` | Archives connues du control file (`STATUS = 'A'`, hors destinations standby) |
| `V$BACKUP` | Datafiles restes en mode sauvegarde (`BEGIN BACKUP` non ferme) |
| `V$RECOVERY_FILE_DEST` | Taille, occupation et espace recuperable de la FRA |
| `V$RMAN_BACKUP_JOB_DETAILS` | Sauvegardes RMAN tracees dans le control file |
| `V$PARAMETER` / `V$SPPARAMETER` | Valeurs actives en memoire, comparees a celles du SPFILE via `DISPLAY_VALUE` |
| `V$DIAG_ALERT_EXT` | Contenu de l'alert.log interrogeable en SQL |
| `DBA_DATA_FILES` | Taille, `AUTOEXTENSIBLE` et `MAXBYTES` de chaque datafile |
| `DBA_FREE_SPACE` | Espace libre restant par tablespace permanent |
| `DBA_TEMP_FILES` / `DBA_TEMP_FREE_SPACE` | Tempfiles, et espace de tri libre extents reutilisables deduits |
| `DBA_TABLESPACES` | Nature (permanent, UNDO, temporaire), statut, taille de bloc, `BIGFILE` |
| `DBA_USERS` | Comptes, avec `ORACLE_MAINTAINED` pour isoler les schemas applicatifs |
| `DBA_OBJECTS` / `DBA_SEGMENTS` | Objets applicatifs, statut INVALID, espace occupe |

---

## Pour aller plus loin

- **Theorie complete** : [Carrousel M1.12 sur LinkedIn](https://www.linkedin.com/posts/activity-7431597458876628992-hmKZ)
- **Module precedent** : [M1.11 - Schemas et Utilisateurs Oracle](../M1.11-Schemas-Utilisateurs/)
- **Voir aussi** : [M1.1 - Instance vs Database](../M1.1-Instance-vs-Database/), le point de depart de toute la serie
- **Prochain module** : M2.1 - STARTUP - Demarrer une Instance (Module 2 : Gestion de l'Instance)
- **Documentation Oracle** : [Starting Up and Shutting Down](https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/starting-up-and-shutting-down.html)

---

## A propos

**Auteur** : Omar SALL - DBA Oracle & Responsable Applications
**Experience** : 10+ ans en production critique (collectivites territoriales)
**Formation basee sur** : Formations ib Cegos (3000EUR+) + Livres Oracle 19c (ENI)

---

**#DBSentinelAcademy** | **#DBSA_M1_12** | Formation Oracle gratuite en francais
