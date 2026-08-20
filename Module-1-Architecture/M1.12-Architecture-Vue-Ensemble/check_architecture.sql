-- ============================================================================
-- SCRIPT     : check_architecture.sql
-- MODULE     : M1.12 - Architecture Oracle, vue d'ensemble
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @check_architecture.sql
-- ============================================================================
-- OBJET      : Etat des lieux des 4 piliers de l'architecture en une page.
--              Dit OU regarder ; les scripts des modules M1.1 a M1.11
--              disent QUOI corriger.
--
-- PORTEE     : les vues V$ sont LOCALES a l'instance. En RAC, les piliers 1
--              (memoire, processus, sessions) ne decrivent que l'instance
--              courante ; les piliers 2, 3 et 4 sont a l'echelle de la base.
--              En CDB, les piliers 3 et 4 ne couvrent que le conteneur
--              courant, rappele dans la carte d'identite.
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT =============== ARCHITECTURE ORACLE - LES 4 PILIERS ===============
PROMPT

-- -----------------------------------------------
-- 0. Carte d'identite
-- -----------------------------------------------

COL nom_base    FORMAT A12  HEAD "Base"
COL nom_inst    FORMAT A16  HEAD "Instance"
COL conteneur   FORMAT A16  HEAD "Conteneur"
COL statut      FORMAT A12  HEAD "Statut"
COL ouverture   FORMAT A22  HEAD "Ouverture"
COL archivage   FORMAT A17  HEAD "Archivage"
COL vers_oracle FORMAT A12  HEAD "Version"
COL uptime      FORMAT A16  HEAD "Demarree depuis"

SELECT d.name                                                     AS nom_base
      ,i.instance_name                                            AS nom_inst
      -- Sur une base non-CDB, CON_NAME renvoie le nom de la base : sans le
      -- test sur V$DATABASE.CDB, la colonne repeterait simplement la premiere.
      ,CASE WHEN d.cdb = 'YES'
            THEN NVL(SYS_CONTEXT('USERENV', 'CON_NAME'), '-')
            ELSE 'Non-CDB'
       END                                                        AS conteneur
      ,i.status                                                   AS statut
      ,d.open_mode                                                AS ouverture
      -- NOARCHIVELOG est le fait le plus grave que ce script puisse
      -- afficher : aucune restauration a une date choisie n'est possible.
      ,d.log_mode || CASE WHEN d.log_mode <> 'ARCHIVELOG'
                          THEN '  !!' ELSE '' END                 AS archivage
      ,i.version                                                  AS vers_oracle
      ,TRIM(TO_CHAR(TRUNC(SYSDATE - i.startup_time), '9990'))
       || ' j '
       || TRIM(TO_CHAR(TRUNC(MOD((SYSDATE - i.startup_time) * 24, 24)), '90'))
       || ' h'                                                    AS uptime
  FROM v$database d
 CROSS JOIN v$instance i
;

PROMPT
PROMPT  PILIER 1 - INSTANCE : memoire et processus (perdus au SHUTDOWN)
PROMPT

-- -----------------------------------------------
-- 1. Instance
--    Chaque ligne part de DUAL avec des sous-requetes scalaires : melanger
--    un agregat et une sous-requete dans un meme SELECT donne ORA-00937.
--    MAX() sur chacune : en CDB, V$PARAMETER peut renvoyer une ligne par
--    conteneur et lever ORA-01427.
-- -----------------------------------------------

COL composant FORMAT A26  HEAD "Composant"
COL mesure    FORMAT A14  HEAD "Mesure"
COL detail    FORMAT A58  HEAD "Detail"

SELECT 'SGA (memoire partagee)'                                   AS composant
      ,LPAD(TRIM(TO_CHAR((SELECT SUM(value)/1048576 FROM v$sga),
             '999,999')) || ' MB', 14)                            AS mesure
      ,CASE
            WHEN (SELECT MAX(TO_NUMBER(value)) FROM v$parameter
                   WHERE name = 'memory_target') > 0
            THEN 'AMM actif'
            WHEN (SELECT MAX(TO_NUMBER(value)) FROM v$parameter
                   WHERE name = 'sga_target') > 0
            THEN 'ASMM actif'
            ELSE 'Gestion manuelle des pools'
       END
       -- Part de SGA pas encore attribuee a un pool : la marge dont disposent
       -- Buffer Cache et Shared Pool pour s'etendre. Zero est le cas courant
       -- en regime etabli, et n'a rien d'inquietant : le dire evite de faire
       -- lire un manque de memoire la ou il n'y en a pas.
       || CASE WHEN NVL((SELECT MAX(current_size)
                           FROM v$sga_dynamic_free_memory), 0) = 0
               THEN ', entierement distribuee aux pools'
               ELSE ', ' || TRIM(TO_CHAR((SELECT MAX(current_size)/1048576
                                            FROM v$sga_dynamic_free_memory),
                            '999,999')) || ' MB non attribues'
          END                                                     AS detail
  FROM dual
UNION ALL
SELECT 'PGA (memoire privee)'
      ,LPAD(TRIM(TO_CHAR((SELECT MAX(value)/1048576 FROM v$pgastat
                           WHERE name = 'total PGA allocated'),
             '999,999')) || ' MB', 14)
      -- La PGA peut depasser sa cible : elle n'est pas un plafond dur.
      ,CASE WHEN NVL((SELECT MAX(TO_NUMBER(value)) FROM v$parameter
                       WHERE name = 'pga_aggregate_target'), 0) = 0
            THEN 'Pilotee par MEMORY_TARGET'
            ELSE 'Cible ' || TRIM(TO_CHAR(
                 (SELECT MAX(TO_NUMBER(value))/1048576 FROM v$parameter
                   WHERE name = 'pga_aggregate_target'), '999,999'))
                 || ' MB, atteinte a ' || TRIM(TO_CHAR(
                 (SELECT MAX(p.value) * 100
                         / NULLIF(MAX(TO_NUMBER(t.value)), 0)
                    FROM v$pgastat p, v$parameter t
                   WHERE p.name = 'total PGA allocated'
                     AND t.name = 'pga_aggregate_target'), '9990'))
                 || '%'
       END
  FROM dual
UNION ALL
-- TRIM sur NAME : V$BGPROCESS.NAME est un CHAR complete par des blancs sur
-- plusieurs versions. Sans TRIM, aucun nom ne matche et le script annonce
-- une instance en peril sur une base parfaitement saine.
SELECT 'Processus background'
      ,LPAD(TRIM(TO_CHAR((SELECT COUNT(*) FROM v$bgprocess
                           WHERE paddr <> '00'), '999,999')), 14)
      ,CASE WHEN (SELECT COUNT(*) FROM v$bgprocess WHERE paddr <> '00') = 0
            THEN 'V$BGPROCESS illisible depuis ce conteneur'
            WHEN (SELECT COUNT(*) FROM v$bgprocess
                   WHERE paddr <> '00'
                     AND TRIM(name) IN ('PMON','SMON','LGWR','CKPT','DBW0')) = 5
            THEN 'PMON, SMON, LGWR, CKPT, DBW0 : tous actifs'
            ELSE '!! Manquant : ' || NVL((SELECT LISTAGG(c.n, ' ')
                                            WITHIN GROUP (ORDER BY c.n)
                   FROM (SELECT 'PMON' AS n FROM dual UNION ALL
                         SELECT 'SMON' FROM dual UNION ALL
                         SELECT 'LGWR' FROM dual UNION ALL
                         SELECT 'CKPT' FROM dual UNION ALL
                         SELECT 'DBW0' FROM dual) c
                  WHERE NOT EXISTS (SELECT 1 FROM v$bgprocess b
                                     WHERE b.paddr <> '00'
                                       AND TRIM(b.name) = c.n)), '-')
       END
  FROM dual
UNION ALL
-- Deux compteurs a ne pas confondre : les connexions applicatives d'un cote,
-- le total face au parametre SESSIONS de l'autre. V$RESOURCE_LIMIT compte
-- aussi les sessions des processus background, d'ou un ecart important.
SELECT 'Sessions utilisateur'
      ,LPAD(TRIM(TO_CHAR((SELECT COUNT(*) FROM v$session
                           WHERE type = 'USER'), '999,999')), 14)
      ,TRIM(TO_CHAR((SELECT COUNT(*) FROM v$session
                      WHERE type = 'USER' AND status = 'ACTIVE'), '999,999'))
       || ' active(s), '
       || TRIM(TO_CHAR(NVL((SELECT MAX(TO_NUMBER(current_utilization))
                              FROM v$resource_limit
                             WHERE resource_name = 'sessions'), 0), '999,999'))
       || ' au total avec les background'
  FROM dual
UNION ALL
-- Le pic depuis le demarrage vaut mieux que le nombre a l'instant T :
-- c'est lui qui dit si la limite a deja ete frolee.
SELECT 'Pic de sessions atteint'
      ,LPAD(TRIM(TO_CHAR(NVL((SELECT MAX(TO_NUMBER(max_utilization))
                                FROM v$resource_limit
                               WHERE resource_name = 'sessions'), 0),
             '999,999')), 14)
      ,'Sur une limite de '
       || NVL((SELECT MAX(CASE WHEN TRIM(limit_value) = 'UNLIMITED'
                               THEN 'illimitee'
                               ELSE TRIM(TO_CHAR(TO_NUMBER(TRIM(limit_value)),
                                                 '999,999'))
                          END)
                 FROM v$resource_limit
                WHERE resource_name = 'sessions'), 'inconnue')
       || ' (parametre SESSIONS)'
  FROM dual
;

PROMPT
PROMPT  PILIER 2 - DATABASE : les fichiers (ce qui survit au SHUTDOWN)
PROMPT

-- -----------------------------------------------
-- 2. Fichiers physiques
-- -----------------------------------------------

COL categorie FORMAT A26   HEAD "Type de fichier"
COL nb        FORMAT 999,999 HEAD "Nb"
COL volume    FORMAT A14   HEAD "Volume"
COL constat   FORMAT A56   HEAD "Constat"

SELECT 'Datafiles'                                                AS categorie
      ,f.nb                                                       AS nb
      ,LPAD(TRIM(TO_CHAR(f.go, '999,990.9')) || ' GB', 14)        AS volume
      -- Alias a_recuperer / hors_ligne : OFFLINE est un mot reserve Oracle,
      -- inutilisable comme alias de colonne.
      ,CASE WHEN f.a_recuperer > 0
            THEN '!! ' || TRIM(TO_CHAR(f.a_recuperer, '999,999'))
                 || ' datafile(s) en RECOVER : base incomplete'
            WHEN f.hors_ligne > 0
            THEN '!! ' || TRIM(TO_CHAR(f.hors_ligne, '999,999'))
                 || ' datafile(s) OFFLINE'
            ELSE 'Tous ONLINE'
       END                                                        AS constat
  FROM (SELECT COUNT(*) AS nb
              ,SUM(bytes)/1073741824 AS go
              ,SUM(CASE WHEN status = 'RECOVER' THEN 1 ELSE 0 END) AS a_recuperer
              ,SUM(CASE WHEN status = 'OFFLINE' THEN 1 ELSE 0 END) AS hors_ligne
          FROM v$datafile) f
UNION ALL
SELECT 'Tempfiles'
      ,t.nb
      ,LPAD(TRIM(TO_CHAR(NVL(t.go, 0), '999,990.9')) || ' GB', 14)
      -- Une PDB sans TEMP propre utilise celui de CDB$ROOT : ce n'est pas
      -- une anomalie, et l'annoncer comme telle serait une fausse alerte.
      ,CASE WHEN t.nb = 0 AND SYS_CONTEXT('USERENV', 'CON_ID') > 2
            THEN 'Aucun TEMP propre : la PDB utilise celui du CDB'
            WHEN t.nb = 0
            THEN '!! Aucun tempfile : tout tri echoue en ORA-01652'
            ELSE 'Espace de tri des requetes'
       END
  FROM (SELECT COUNT(*) AS nb, SUM(bytes)/1073741824 AS go
          FROM v$tempfile) t
UNION ALL
SELECT 'Control files'
      ,c.nb
      ,LPAD('-', 14)
      -- Oracle n'arbitre pas entre les copies : il les ecrit toutes et exige
      -- qu'elles soient toutes lisibles et coherentes. Plusieurs copies ne
      -- donnent pas un vote, elles donnent des exemplaires a recopier.
      ,CASE WHEN c.nb = 1
            THEN '!! COPIE UNIQUE : restauration obligatoire si perdue'
            WHEN c.emplacements = 1
            THEN '!! ' || TRIM(TO_CHAR(c.nb, '999,999'))
                 || ' copies dans le meme repertoire'
            WHEN c.nb = 2
            THEN '2 copies sur 2 emplacements (3 recommandees)'
            ELSE TRIM(TO_CHAR(c.nb, '999,999')) || ' copies sur '
                 || TRIM(TO_CHAR(c.emplacements, '999,999')) || ' emplacements'
       END
  FROM (SELECT COUNT(*) AS nb
              -- NULLIF : un nom sans separateur donnerait SUBSTR(...,1,-1),
              -- donc NULL, et ferait disparaitre l'emplacement du comptage.
              ,COUNT(DISTINCT NVL(SUBSTR(name, 1,
                 NULLIF(GREATEST(INSTR(name, '/', -1),
                                 INSTR(name, '\', -1)), 0) - 1), name))
                                                       AS emplacements
          FROM v$controlfile) c
UNION ALL
SELECT 'Groupes de redo logs'
      ,l.nb
      -- BYTES est la taille d'UN membre : le volume disque reel se calcule
      -- en multipliant par le nombre de membres du groupe.
      ,LPAD(TRIM(TO_CHAR(l.go, '999,990.9')) || ' GB', 14)
      ,CASE WHEN l.mono > 0
            THEN '!! ' || TRIM(TO_CHAR(l.mono, '999,999'))
                 || ' groupe(s) a 1 membre : perte du courant = pertes'
            WHEN l.mo_min <> l.mo_max
            THEN TRIM(TO_CHAR(l.min_membres, '999')) || ' membres par groupe, '
                 || 'tailles inegales a uniformiser'
            ELSE TRIM(TO_CHAR(l.min_membres, '999')) || ' membres par groupe, '
                 || TRIM(TO_CHAR(l.mo_max, '999,999')) || ' MB chacun'
       END
  FROM (SELECT COUNT(*) AS nb
              ,SUM(bytes * members)/1073741824 AS go
              ,MIN(members) AS min_membres
              ,MIN(bytes)/1048576 AS mo_min
              ,MAX(bytes)/1048576 AS mo_max
              ,SUM(CASE WHEN members < 2 THEN 1 ELSE 0 END) AS mono
          FROM v$log) l
UNION ALL
-- Un CROSS JOIN plutot qu'une sous-requete scalaire : melanger agregat et
-- sous-requete dans un SELECT sans GROUP BY leve ORA-00937.
-- STATUS = 'A' (available) plutot que DELETED : c'est l'etat que le control
-- file considere comme utilisable. Ni l'un ni l'autre ne prouve la presence
-- physique du fichier, qu'un rm manuel ferait disparaitre sans le dire.
SELECT 'Archives connues'
      ,a.nb
      ,LPAD('-', 14)
      -- Une base repassee en NOARCHIVELOG conserve dans son control file les
      -- enregistrements des archives produites avant : les afficher sans le
      -- dire laisserait croire que l'archivage fonctionne encore.
      ,CASE WHEN d.log_mode <> 'ARCHIVELOG' AND a.nb > 0
            THEN '!! NOARCHIVELOG : archives d''un mode anterieur'
            WHEN d.log_mode <> 'ARCHIVELOG'
            THEN '!! NOARCHIVELOG : aucune restauration possible'
            WHEN a.nb = 0
            THEN '!! ARCHIVELOG actif mais aucune archive presente'
            ELSE 'Depuis le ' || TO_CHAR(a.plus_ancienne, 'DD/MM/YYYY')
                 || ' (control file)'
       END
  FROM (SELECT COUNT(*) AS nb, MIN(first_time) AS plus_ancienne
          FROM v$archived_log
         WHERE status = 'A'
           AND standby_dest = 'NO') a
 CROSS JOIN v$database d
;

PROMPT
PROMPT  PILIER 3 - TABLESPACES : SYSTEM, SYSAUX, UNDO, TEMP et les tendus
PROMPT

-- -----------------------------------------------
-- 3. Tablespaces
--    Calcul fait sur DBA_DATA_FILES et non sur DBA_TABLESPACE_USAGE_METRICS :
--    cette derniere rapporte l'occupation a la limite PHYSIQUE du datafile
--    (32 GB en blocs de 8 K) des qu'un fichier est en MAXSIZE UNLIMITED.
--    Un SYSTEM de 1,4 GB rempli a 85% de son espace alloue y apparait a 4%.
-- -----------------------------------------------

COL tablespace FORMAT A20  HEAD "Tablespace"
COL nature     FORMAT A11  HEAD "Nature"
COL occupe     FORMAT A13  HEAD "Occupe"
COL alloue     FORMAT A13  HEAD "Alloue"
COL pct_all    FORMAT A6   HEAD "% All"
COL plafond    FORMAT A13  HEAD "Plafond"
COL pct_max    FORMAT A6   HEAD "% Max"
COL verdict    FORMAT A46  HEAD "Verdict"

SELECT r.tablespace                                               AS tablespace
      ,r.nature                                                   AS nature
      ,r.occupe                                                   AS occupe
      ,r.alloue                                                   AS alloue
      ,r.pct_all                                                  AS pct_all
      ,r.plafond                                                  AS plafond
      ,r.pct_max                                                  AS pct_max
      ,r.verdict                                                  AS verdict
  FROM (
    SELECT t.ts                                                   AS tablespace
          ,t.nature                                               AS nature
          -- Bascule en GB au-dela de 976 GB : le format MB afficherait ####
          ,LPAD(CASE WHEN t.mo_occupe >= 1000000
                     THEN TRIM(TO_CHAR(t.mo_occupe/1024, '999,990.9')) || ' GB'
                     ELSE TRIM(TO_CHAR(t.mo_occupe, '999,999')) || ' MB'
                END, 13)                                          AS occupe
          ,LPAD(CASE WHEN t.mo_alloue >= 1000000
                     THEN TRIM(TO_CHAR(t.mo_alloue/1024, '999,990.9')) || ' GB'
                     ELSE TRIM(TO_CHAR(t.mo_alloue, '999,999')) || ' MB'
                END, 13)                                          AS alloue
          ,LPAD(TRIM(TO_CHAR(t.pct_all, '990.0')) || '%', 6)      AS pct_all
          -- Le plafond est TOUJOURS chiffre. MAXSIZE UNLIMITED n'est pas un
          -- espace infini : Oracle y inscrit la limite physique du fichier.
          -- Afficher "ILLIMITE" masquerait un tablespace a 28 GB dont il ne
          -- reste que 4 GB.
          ,LPAD(CASE WHEN t.autoext = 0 THEN 'FIXE'
                     WHEN t.mo_plafond >= 1000000
                     THEN TRIM(TO_CHAR(t.mo_plafond/1024, '999,990.9')) || ' GB'
                     ELSE TRIM(TO_CHAR(t.mo_plafond, '999,999')) || ' MB'
                END, 13)                                          AS plafond
          ,LPAD(TRIM(TO_CHAR(t.pct_max, '990.0')) || '%', 6)      AS pct_max
          ,CASE
                -- Tablespaces dont un taux eleve est le regime normal :
                -- leurs extents liberes restent alloues pour etre reutilises.
                -- Les signaler en rouge chaque matin ferait ignorer le reste.
                WHEN t.nature = 'UNDO' AND t.pct_max >= 95
                THEN '!! UNDO au plafond : ORA-30036       (M1.10)'
                WHEN t.nature = 'UNDO'
                THEN 'Extents expires recycles en interne (M1.10)'
                WHEN t.nature = 'TEMPORAIRE' AND t.pct_max >= 95
                THEN '!! TEMP sature, extents deduits      (M1.9)'
                WHEN t.nature = 'TEMPORAIRE'
                THEN 'Extents reutilisables deduits        (M1.9)'
                WHEN t.statut = 'READ ONLY'
                THEN 'Lecture seule : n''a plus vocation a grandir'
                WHEN t.statut = 'OFFLINE'
                THEN 'Hors ligne : occupation non mesurable'
                -- Sans autoextend, le plafond est deja atteint
                WHEN t.autoext = 0 AND t.pct_all >= 95
                THEN '!! CRITIQUE : plein, sans autoextend (M1.6)'
                WHEN t.autoext = 0 AND t.pct_all >= 85
                THEN '!! Activer AUTOEXTEND ou un fichier  (M1.6)'
                -- Plafond en vue : l'action depend de son origine. Un MAXSIZE
                -- choisi se releve. La limite physique du fichier, non : il
                -- faut un datafile de plus - sauf en BIGFILE, qui n'en accepte
                -- qu'un seul (ORA-32771) et se redimensionne a la place.
                WHEN t.bigfile = 1 AND t.pct_max >= 85
                THEN '!! BIGFILE : relever MAXSIZE (1 seul fichier)'
                WHEN t.plafond_fichier = 1 AND t.pct_max >= 95
                THEN '!! CRITIQUE : ajouter un datafile    (M1.6)'
                WHEN t.plafond_fichier = 1 AND t.pct_max >= 85
                THEN '!! Ajouter un datafile : MAXSIZE au max'
                WHEN t.pct_max >= 95
                THEN '!! CRITIQUE : relever MAXSIZE        (M1.6)'
                WHEN t.pct_max >= 85
                THEN '!! Relever MAXSIZE ou un fichier     (M1.6)'
                WHEN t.pct_max >= 70
                THEN 'Surveiller : le plafond se rapproche'
                -- Plafond encore loin : c'est le disque qui limite
                WHEN t.pct_all >= 90
                THEN 'S''etendra bientot : verifier l''espace disque'
                WHEN t.pct_all >= 85
                THEN 'Surveiller : extension prochaine'
                ELSE 'OK'
           END                                                    AS verdict
          ,t.tri                                                  AS tri
      FROM (
        SELECT x.ts
              ,x.nature
              ,x.statut
              ,ROUND(x.occupe  / 1048576)                         AS mo_occupe
              ,ROUND(x.alloue  / 1048576)                         AS mo_alloue
              ,ROUND(x.plafond / 1048576)                         AS mo_plafond
              ,x.occupe * 100 / NULLIF(x.alloue, 0)               AS pct_all
              ,x.occupe * 100 / NULLIF(x.plafond, 0)              AS pct_max
              ,x.autoext
              ,x.plafond_fichier
              ,x.bigfile
              ,x.tri
          FROM (
            -- Tablespaces permanents et UNDO
            SELECT df.tablespace_name                             AS ts
                  ,CASE WHEN df.tablespace_name = 'SYSTEM' THEN 'SYSTEM'
                        WHEN df.tablespace_name = 'SYSAUX' THEN 'SYSAUX'
                        WHEN ts.contents = 'UNDO'          THEN 'UNDO'
                        ELSE 'APPLICATIF'
                   END                                            AS nature
                  ,ts.status                                      AS statut
                  ,SUM(df.bytes) - NVL(MAX(fr.libre), 0)          AS occupe
                  ,SUM(df.bytes)                                  AS alloue
                  ,SUM(CASE WHEN df.autoextensible = 'YES'
                            THEN GREATEST(df.maxbytes, df.bytes)
                            ELSE df.bytes END)                    AS plafond
                  ,MAX(CASE WHEN df.autoextensible = 'YES' THEN 1 ELSE 0 END)
                                                                  AS autoext
                  -- Plafond issu de la limite physique du fichier et non d'un
                  -- MAXSIZE choisi : signature de MAXSIZE UNLIMITED. Le seuil
                  -- differe entre smallfile (4194302 blocs) et bigfile
                  -- (2^32 blocs) : appliquer le seuil smallfile a un bigfile
                  -- ferait conseiller un datafile de plus, ce qu'Oracle refuse.
                  ,MAX(CASE WHEN df.autoextensible = 'YES'
                             AND df.maxbytes >=
                                 CASE WHEN ts.bigfile = 'YES' THEN 4294967293
                                      ELSE 4194302 END * ts.block_size
                            THEN 1 ELSE 0 END)                    AS plafond_fichier
                  ,MAX(CASE WHEN ts.bigfile = 'YES' THEN 1 ELSE 0 END)
                                                                  AS bigfile
                  ,CASE WHEN df.tablespace_name = 'SYSTEM' THEN 1
                        WHEN df.tablespace_name = 'SYSAUX' THEN 2
                        WHEN ts.contents = 'UNDO'          THEN 3
                        ELSE 5
                   END                                            AS tri
              FROM dba_data_files df
              JOIN dba_tablespaces ts
                ON ts.tablespace_name = df.tablespace_name
              LEFT JOIN (SELECT tablespace_name, SUM(bytes) AS libre
                           FROM dba_free_space
                          GROUP BY tablespace_name) fr
                ON fr.tablespace_name = df.tablespace_name
             GROUP BY df.tablespace_name, ts.contents, ts.block_size
                     ,ts.status, ts.bigfile
            UNION ALL
            -- Tablespaces temporaires : l'occupation se lit dans
            -- DBA_TEMP_FREE_SPACE, seule vue qui deduit les extents liberes
            -- mais conserves pour reutilisation. V$TEMP_SPACE_HEADER.BYTES_USED
            -- est un high water mark qui ne redescend pas et afficherait un
            -- TEMP sain a 100%.
            SELECT tf.tablespace_name
                  ,'TEMPORAIRE'
                  ,ts.status
                  ,GREATEST(SUM(tf.bytes) - NVL(MAX(fs.dispo), 0), 0)
                  ,SUM(tf.bytes)
                  ,SUM(CASE WHEN tf.autoextensible = 'YES'
                            THEN GREATEST(tf.maxbytes, tf.bytes)
                            ELSE tf.bytes END)
                  ,MAX(CASE WHEN tf.autoextensible = 'YES' THEN 1 ELSE 0 END)
                  ,MAX(CASE WHEN tf.autoextensible = 'YES'
                             AND tf.maxbytes >=
                                 CASE WHEN ts.bigfile = 'YES' THEN 4294967293
                                      ELSE 4194302 END * ts.block_size
                            THEN 1 ELSE 0 END)
                  ,MAX(CASE WHEN ts.bigfile = 'YES' THEN 1 ELSE 0 END)
                  ,4
              FROM dba_temp_files tf
              JOIN dba_tablespaces ts
                ON ts.tablespace_name = tf.tablespace_name
              LEFT JOIN (SELECT tablespace_name, SUM(free_space) AS dispo
                           FROM dba_temp_free_space
                          GROUP BY tablespace_name) fs
                ON fs.tablespace_name = tf.tablespace_name
             GROUP BY tf.tablespace_name, ts.block_size, ts.status, ts.bigfile
          ) x
      ) t
     -- Les 4 tablespaces structurants sont toujours affiches. Les applicatifs
     -- ne le sont que si le PLAFOND se rapproche : avec autoextend, occuper
     -- 95% de l'espace alloue est le fonctionnement normal, et filtrer
     -- la-dessus remonterait presque tous les tablespaces de la base.
     WHERE t.tri < 5
        OR t.pct_max >= 70
        OR (t.autoext = 0 AND t.pct_all >= 85)
     ORDER BY t.tri, t.pct_max DESC
  ) r
 WHERE ROWNUM <= 25
;

PROMPT
PROMPT  PILIER 4 - ORGANISATION LOGIQUE : qui possede quoi
PROMPT

-- -----------------------------------------------
-- 4. Schemas applicatifs
--    Filtre sur DBA_USERS.ORACLE_MAINTAINED, jamais sur DBA_OBJECTS :
--    Oracle cree lui-meme des milliers d'objets marques 'N'.
--    Une seule passe sur DBA_OBJECTS et DBA_SEGMENTS : sur une base a
--    plusieurs centaines de milliers d'objets, les rescanner coute cher.
-- -----------------------------------------------

COL indicateur FORMAT A46  HEAD "Indicateur"
COL valeur     FORMAT A16  HEAD "Valeur"
COL lecture    FORMAT A50  HEAD "Lecture"

-- NVL sur chaque SUM : sur une base sans aucun schema applicatif, SUM()
-- renvoie NULL et non 0. Les tests "= 0" seraient alors UNKNOWN et le
-- script afficherait ses deux alertes sur une base parfaitement propre.
WITH obj AS (
    SELECT COUNT(*)                                               AS total
          ,NVL(SUM(CASE WHEN o.status = 'INVALID' THEN 1 ELSE 0 END), 0)
                                                                  AS invalides
      FROM dba_objects o
      JOIN dba_users u ON u.username = o.owner
                      AND u.oracle_maintained = 'N'
     -- La corbeille contient des objets droppes : les compter gonflerait
     -- l'inventaire et ferait apparaitre de faux INVALID.
     WHERE o.object_name NOT LIKE 'BIN$%'
), seg AS (
    SELECT NVL(SUM(s.bytes), 0)                                   AS octets
          ,NVL(SUM(CASE WHEN s.tablespace_name IN ('SYSTEM', 'SYSAUX')
                        THEN 1 ELSE 0 END), 0)                    AS dans_system
      FROM dba_segments s
      JOIN dba_users u ON u.username = s.owner
                      AND u.oracle_maintained = 'N'
), usr AS (
    SELECT COUNT(*) AS nb FROM dba_users WHERE oracle_maintained = 'N'
)
SELECT 'Schemas applicatifs'                                      AS indicateur
      ,LPAD(TRIM(TO_CHAR(usr.nb, '999,999,999')), 16)             AS valeur
      ,'Comptes Oracle internes exclus            (M1.11)'        AS lecture
  FROM usr
UNION ALL
SELECT 'Objets applicatifs'
      ,LPAD(TRIM(TO_CHAR(obj.total, '999,999,999')), 16)
      ,'Tables, index, vues, PL/SQL de ces schemas'
  FROM obj
UNION ALL
SELECT 'Objets INVALID'
      ,LPAD(TRIM(TO_CHAR(obj.invalides, '999,999,999')), 16)
      ,CASE WHEN obj.invalides = 0
            THEN 'OK : rien a recompiler'
            ELSE 'Recompilation auto au 1er appel, qui peut echouer'
       END
  FROM obj
UNION ALL
SELECT 'Espace occupe par ces schemas'
      ,LPAD(TRIM(TO_CHAR(seg.octets/1073741824, '999,999,990.9')) || ' GB', 16)
      ,'Segments reellement alloues sur disque'
  FROM seg
UNION ALL
SELECT 'Segments applicatifs dans SYSTEM ou SYSAUX'
      ,LPAD(TRIM(TO_CHAR(seg.dans_system, '999,999,999')), 16)
      ,CASE WHEN seg.dans_system = 0
            THEN 'OK : SYSTEM reste au dictionnaire Oracle'
            ELSE '!! Sature SYSTEM : deplacer ces objets    (M1.11)'
       END
  FROM seg
;

PROMPT
PROMPT ======================== SEUILS ET SUITE ========================
PROMPT
PROMPT  % All = occupe / alloue   : Oracle va-t-il devoir etendre le fichier
PROMPT  % Max = occupe / plafond  : lui reste-t-il le droit de le faire
PROMPT
PROMPT  Un datafile smallfile s'arrete a 32 GB en blocs de 8 K, meme declare
PROMPT  en MAXSIZE UNLIMITED : le plafond affiche est donc toujours reel.
PROMPT  A saturation, relever MAXSIZE s'il a ete choisi ; sinon ajouter un
PROMPT  datafile, ou creer un tablespace BIGFILE et y deplacer les segments.
PROMPT
PROMPT  UNDO et TEMP conservent leurs extents pour les reutiliser : un taux
PROMPT  eleve y est normal. Voir M1.10 et M1.9 pour leur dimensionnement.
PROMPT
PROMPT  Pilier 3 : 25 lignes au maximum, les plus proches de leur plafond.
PROMPT  Prochaine etape : @daily_healthcheck.sql pour l'etat des 24h.
PROMPT
PROMPT =================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_12
