-- ============================================================================
-- SCRIPT     : v_startup_readiness.sql
-- MODULE     : M1.12 - Architecture Oracle, vue d'ensemble
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_startup_readiness.sql
-- ============================================================================
-- OBJET      : Si tu redemarrais maintenant, ou est-ce que ca casserait ?
--
-- IMPORTANT  : ce script s'execute sur une base OUVERTE. Il ne remplace pas
--              le diagnostic d'une base qui refuse de demarrer : dans ce cas
--              seules repondent les vues de la phase deja atteinte
--              (V$PARAMETER et V$SGA en NOMOUNT, V$DATAFILE et V$LOG une fois
--              montee), et l'alert.log fait foi.
--              C'est un audit PREVENTIF, a lancer AVANT un arret planifie.
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ============ REDEMARRAGE : CE QUI TIENDRAIT, CE QUI CASSERAIT ============
PROMPT
PROMPT  PHASE 1 - NOMOUNT : lecture des parametres et allocation de la SGA
PROMPT

-- -----------------------------------------------
-- 1. Phase NOMOUNT
--    Ce qui compte ici n'est pas l'etat courant de la memoire, c'est ce
--    qu'Oracle relira au prochain demarrage : le fichier de parametres.
-- -----------------------------------------------

COL controle FORMAT A44  HEAD "Point de controle"
COL etat     FORMAT A70  HEAD "Etat"

SELECT 'Fichier de parametres utilise'                            AS controle
      ,CASE WHEN p.spf IS NULL
            THEN '!! PFILE : toute modif ALTER SYSTEM sera perdue'
            -- Seul le nom du fichier : le chemin complet deborderait
            ELSE 'OK : SPFILE ' || SUBSTR(p.spf,
                 GREATEST(INSTR(p.spf, '/', -1), INSTR(p.spf, '\', -1)) + 1)
       END                                                        AS etat
  FROM (SELECT MAX(value) AS spf FROM v$parameter
         WHERE name = 'spfile') p
UNION ALL
-- Le controle le plus utile de cette phase : un ALTER SYSTEM passe en
-- SCOPE=MEMORY tient jusqu'au SHUTDOWN, puis disparait sans bruit.
-- La comparaison porte sur DISPLAY_VALUE des deux cotes : V$PARAMETER
-- stocke 2147483648 la ou le SPFILE garde "2G", et comparer les VALUE
-- brutes declarerait perdu un parametre parfaitement persistant.
SELECT 'Parametres actifs mais absents du SPFILE'
      ,CASE WHEN SYS_CONTEXT('USERENV', 'CON_ID') > 2
            THEN 'En PDB : les valeurs persistent dans PDB_SPFILE$'
            WHEN COUNT(*) = 0
            THEN 'OK : la memoire et le SPFILE disent la meme chose'
            ELSE '!! ' || TRIM(TO_CHAR(COUNT(*), '999,999'))
                 || ' parametre(s) perdu(s) au STARTUP : '
                 || SUBSTR(MIN(name), 1, 24)
       END
  FROM (
    SELECT p.name
      FROM v$parameter p
     WHERE p.ismodified = 'SYSTEM_MOD'
       AND NOT EXISTS (SELECT 1
                         FROM v$spparameter s
                        WHERE s.name = p.name
                          AND s.isspecified = 'TRUE'
                          AND NVL(s.display_value, '~')
                              = NVL(p.display_value, '~'))
  )
UNION ALL
SELECT 'Dimensionnement memoire declare'
      ,'SGA ' || TRIM(TO_CHAR((SELECT SUM(value)/1048576 FROM v$sga), '999,999'))
       || ' MB + PGA cible '
       || TRIM(TO_CHAR(NVL((SELECT MAX(TO_NUMBER(value))/1048576
                              FROM v$parameter
                             WHERE name = 'pga_aggregate_target'), 0), '999,999'))
       || ' MB a reserver en RAM au STARTUP'
  FROM dual
;

PROMPT
PROMPT  PHASE 2 - MOUNT : ouverture des control files
PROMPT

-- -----------------------------------------------
-- 2. Phase MOUNT
--    Oracle lit TOUS les control files declares et exige qu'ils soient
--    tous lisibles et coherents. Il n'arbitre pas entre les copies : elles
--    ne votent pas, elles servent d'exemplaires a recopier.
-- -----------------------------------------------

SELECT 'Nombre de copies du control file'                         AS controle
      ,CASE WHEN c.nb >= 3
            THEN 'OK : ' || TRIM(TO_CHAR(c.nb, '999,999')) || ' copies'
            WHEN c.nb = 2
            THEN '2 copies : conforme, 3 recommandees par Oracle'
            ELSE '!! COPIE UNIQUE : restauration obligatoire si perdue'
       END                                                        AS etat
  FROM (SELECT COUNT(*) AS nb FROM v$controlfile) c
UNION ALL
SELECT 'Repartition sur des emplacements distincts'
      ,CASE WHEN c.emplacements = 1 AND c.nb > 1
            THEN '!! Toutes les copies dans le meme repertoire'
            WHEN c.nb = 1
            THEN 'Sans objet : une seule copie declaree'
            ELSE 'OK : ' || TRIM(TO_CHAR(c.emplacements, '999,999'))
                 || ' emplacements differents'
       END
  -- NULLIF : un nom sans separateur donnerait SUBSTR(...,1,-1) donc NULL,
  -- et l'emplacement disparaitrait du comptage.
  FROM (SELECT COUNT(*) AS nb
              ,COUNT(DISTINCT NVL(SUBSTR(name, 1,
                 NULLIF(GREATEST(INSTR(name, '/', -1),
                                 INSTR(name, '\', -1)), 0) - 1), name))
                                                       AS emplacements
          FROM v$controlfile) c
UNION ALL
SELECT 'Taille des copies'
      ,CASE WHEN c.mini = c.maxi OR c.mini IS NULL
            THEN 'Toutes identiques : '
                 || TRIM(TO_CHAR(c.maxi, '999,990.9')) || ' MB par copie'
            ELSE '!! Tailles differentes : de '
                 || TRIM(TO_CHAR(c.mini, '999,990.9')) || ' a '
                 || TRIM(TO_CHAR(c.maxi, '999,990.9')) || ' MB'
       END
  FROM (SELECT MIN(block_size * file_size_blks) / 1048576 AS mini
              ,MAX(block_size * file_size_blks) / 1048576 AS maxi
          FROM v$controlfile) c
;

PROMPT
PROMPT  PHASE 3 - OPEN : ouverture des datafiles et des redo logs
PROMPT

-- -----------------------------------------------
-- 3. Phase OPEN
-- -----------------------------------------------

SELECT 'Datafiles accessibles (en-tetes)'                         AS controle
      ,CASE WHEN h.en_erreur > 0
            THEN '!! ' || TRIM(TO_CHAR(h.en_erreur, '999,999'))
                 || ' fichier(s) en erreur : ORA-01157 au prochain OPEN'
            ELSE 'OK : ' || TRIM(TO_CHAR(h.nb, '999,999'))
                 || ' en-tetes lus sans erreur'
       END                                                        AS etat
  FROM (SELECT COUNT(*) AS nb
              ,SUM(CASE WHEN error IS NOT NULL THEN 1 ELSE 0 END) AS en_erreur
          FROM v$datafile_header
         -- Un fichier hors ligne peut porter une erreur d'en-tete sans que
         -- cela empeche l'ouverture de la base.
         WHERE status <> 'OFFLINE') h
UNION ALL
SELECT 'Datafiles necessitant un recovery'
      ,CASE WHEN COUNT(*) = 0
            THEN 'OK : aucun fichier en RECOVER'
            ELSE '!! ' || TRIM(TO_CHAR(COUNT(*), '999,999'))
                 || ' fichier(s) : l''OPEN exigera un RECOVER manuel'
       END
  FROM v$datafile
 WHERE status = 'RECOVER'
UNION ALL
-- Le piege classique : un BEGIN BACKUP jamais suivi d'un END BACKUP.
-- Un SHUTDOWN propre refuse alors de s'executer (ORA-01149) ; apres un
-- arret brutal, c'est l'ouverture qui echoue (ORA-01113).
SELECT 'Datafiles restes en mode sauvegarde'
      ,CASE WHEN COUNT(*) = 0
            THEN 'OK : aucun BEGIN BACKUP en cours'
            ELSE '!! ' || TRIM(TO_CHAR(COUNT(*), '999,999'))
                 || ' fichier(s) en BACKUP MODE : SHUTDOWN bloque (ORA-01149)'
       END
  FROM v$backup
 WHERE status = 'ACTIVE'
UNION ALL
SELECT 'Membres de redo logs indisponibles'
      ,CASE WHEN COUNT(*) = 0
            THEN 'OK : tous les membres sont lisibles'
            ELSE '!! ' || TRIM(TO_CHAR(COUNT(*), '999,999'))
                 || ' membre(s) INVALID ou DELETED a recreer'
       END
  FROM v$logfile
 WHERE status IN ('INVALID', 'DELETED')
UNION ALL
SELECT 'Groupes de redo a membre unique'
      ,CASE WHEN COUNT(*) = 0
            THEN 'OK : chaque groupe est multiplexe'
            ELSE '!! ' || TRIM(TO_CHAR(COUNT(*), '999,999'))
                 || ' groupe(s) sans copie de secours'
       END
  FROM v$log
 WHERE members < 2
UNION ALL
-- Les tempfiles n'empechent pas l'ouverture, mais leur absence ne se
-- decouvre qu'au premier ORDER BY de la journee.
SELECT 'Tempfiles declares'
      ,CASE WHEN COUNT(*) = 0 AND SYS_CONTEXT('USERENV', 'CON_ID') > 2
            THEN 'Aucun TEMP propre : la PDB utilise celui du CDB'
            WHEN COUNT(*) = 0
            THEN '!! Aucun tempfile : ORA-01652 des le premier tri'
            ELSE 'OK : ' || TRIM(TO_CHAR(COUNT(*), '999,999'))
                 || ' tempfile(s), l''OPEN n''en depend pas'
       END
  FROM v$tempfile
;

PROMPT
PROMPT  A quelle phase se lit chaque erreur de demarrage :
PROMPT

-- -----------------------------------------------
-- 4. Table de lecture des erreurs de STARTUP
-- -----------------------------------------------

COL phase       FORMAT A10  HEAD "Phase"
COL code_ora    FORMAT A12  HEAD "Erreur"
COL cause       FORMAT A46  HEAD "Cause reelle"
COL ou_chercher FORMAT A48  HEAD "Ou chercher"

SELECT 'NOMOUNT'                                                  AS phase
      ,'ORA-01078'                                                AS code_ora
      ,'Fichier de parametres illisible ou absent'                AS cause
      ,'SPFILE/PFILE dans $ORACLE_HOME/dbs'                       AS ou_chercher
  FROM dual
UNION ALL
SELECT 'NOMOUNT', 'ORA-27102'
      ,'SGA non allouable par le systeme'
      ,'RAM libre, shmmax/shmall, /dev/shm, HugePages'
  FROM dual
UNION ALL
SELECT 'MOUNT', 'ORA-00205'
      ,'Un control file declare est introuvable'
      ,'Parametre CONTROL_FILES, puis le disque'
  FROM dual
UNION ALL
SELECT 'MOUNT', 'ORA-00214'
      ,'Copies du control file desynchronisees'
      ,'Repartir de la copie la plus recente'
  FROM dual
UNION ALL
SELECT 'OPEN', 'ORA-01157'
      ,'Un datafile ne peut pas etre identifie'
      ,'V$DATAFILE_HEADER puis le point de montage'
  FROM dual
UNION ALL
SELECT 'OPEN', 'ORA-01113'
      ,'Datafile en mode sauvegarde apres arret brutal'
      ,'ALTER DATABASE END BACKUP (base montee)'
  FROM dual
UNION ALL
SELECT 'OPEN', 'ORA-01589'
      ,'Ouverture impossible sans RESETLOGS'
      ,'RECOVER DATABASE puis OPEN RESETLOGS'
  FROM dual
;

PROMPT
PROMPT ======================== METHODE DE DIAGNOSTIC ========================
PROMPT
PROMPT  Quand STARTUP echoue, monter la base phase par phase pour isoler :
PROMPT
PROMPT    SQL> STARTUP NOMOUNT           echoue ici : parametres ou memoire
PROMPT    SQL> ALTER DATABASE MOUNT      echoue ici : control files
PROMPT    SQL> ALTER DATABASE OPEN       echoue ici : datafiles ou redo logs
PROMPT
PROMPT  A chaque etape franchie, les vues correspondantes redeviennent
PROMPT  interrogeables : V$PARAMETER des NOMOUNT, V$DATAFILE et V$LOG une
PROMPT  fois la base montee. La phase qui echoue designe le composant,
PROMPT  l'alert.log nomme le fichier.
PROMPT
PROMPT  Ce script ne remplace pas cette methode : il verifie AVANT l'arret
PROMPT  ce qui ferait echouer chacune de ces trois etapes.
PROMPT
PROMPT ======================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_12
