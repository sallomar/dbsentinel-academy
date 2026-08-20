-- ============================================================================
-- SCRIPT     : v_sessions_locks.sql
-- MODULE     : M1.12 - Architecture Oracle, vue d'ensemble
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @v_sessions_locks.sql
-- ============================================================================
-- OBJET      : Qui bloque qui, et depuis combien de temps.
--              Une ligne par session bloquante, jamais une ligne par verrou :
--              un compte qui bloque 40 sessions tient sur une seule ligne.
--
-- PORTEE     : V$SESSION est LOCALE a l'instance. En RAC, seules les chaines
--              dont le bloqueur est sur CETTE instance sont detaillees ; les
--              blocages inter-noeuds sont comptes et signales a part, jamais
--              attribues a une session locale portant le meme SID.
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ============== SESSIONS ET BLOCAGES - PHOTO A L'INSTANT T ==============
PROMPT
PROMPT  Repartition des sessions
PROMPT

-- -----------------------------------------------
-- 1. Photographie des sessions
-- -----------------------------------------------

COL categorie FORMAT A36     HEAD "Categorie"
COL nb        FORMAT 999,999 HEAD "Nb"
COL lecture   FORMAT A56     HEAD "Lecture"

SELECT 'Sessions utilisateur ACTIVE'                              AS categorie
      ,COUNT(*)                                                   AS nb
      ,'Une requete est en cours d''execution'                    AS lecture
  FROM v$session
 WHERE type = 'USER'
   AND status = 'ACTIVE'
UNION ALL
SELECT 'Sessions utilisateur INACTIVE'
      ,COUNT(*)
      ,'Connectees sans requete : normal pour un pool applicatif'
  FROM v$session
 WHERE type = 'USER'
   AND status = 'INACTIVE'
UNION ALL
-- Une session inactive depuis des heures est inoffensive... sauf si elle
-- detient un verrou. C'est tout l'objet de la section suivante.
SELECT 'dont inactives depuis plus d''1 h'
      ,COUNT(*)
      ,CASE WHEN COUNT(*) = 0
            THEN 'Aucune session dormante'
            ELSE 'Sans risque, sauf si l''une d''elles bloque (section 2)'
       END
  FROM v$session
 WHERE type = 'USER'
   AND status = 'INACTIVE'
   AND last_call_et > 3600
UNION ALL
-- 'GLOBAL' signale un bloqueur situe sur une autre instance RAC : sans lui,
-- les blocages inter-noeuds seraient invisibles.
SELECT 'Sessions bloquees'
      ,COUNT(*)
      ,CASE WHEN COUNT(*) = 0
            THEN 'OK : personne n''attend personne'
            ELSE '!! En attente de la liberation d''un verrou'
       END
  FROM v$session
 WHERE blocking_session IS NOT NULL
   AND blocking_session_status IN ('VALID', 'GLOBAL')
UNION ALL
SELECT 'dont bloquees par une autre instance'
      ,COUNT(*)
      ,CASE WHEN COUNT(*) = 0
            THEN 'Aucune : le bloqueur est toujours local'
            ELSE '!! RAC : relancer ce script sur l''instance du bloqueur'
       END
  FROM v$session
 WHERE blocking_session IS NOT NULL
   AND blocking_session_status IN ('VALID', 'GLOBAL')
   AND NVL(blocking_instance, TO_NUMBER(SYS_CONTEXT('USERENV', 'INSTANCE')))
       <> TO_NUMBER(SYS_CONTEXT('USERENV', 'INSTANCE'))
UNION ALL
SELECT 'Processus background'
      ,COUNT(*)
      ,'PMON, SMON, DBWn, LGWR, CKPT et les autres    (M1.5)'
  FROM v$session
 WHERE type = 'BACKGROUND'
;

PROMPT
PROMPT  Chaines de blocage : une ligne par session bloquante
PROMPT

-- -----------------------------------------------
-- 2. Qui bloque qui
--    Le verdict repose sur le STATUT DU BLOQUANT, pas sur la duree :
--    un bloquant INACTIVE ne rendra jamais la main tout seul.
--    Le filtre sur l'instance est indispensable : en RAC, un SID distant
--    correspondrait a une session locale sans aucun rapport, et le script
--    designerait un innocent a tuer.
-- -----------------------------------------------

COL bloquant   FORMAT A26  HEAD "Session bloquante"
COL provenance FORMAT A24  HEAD "Provenance"
COL nb_bloq    FORMAT 9,999 HEAD "Bloq."
COL attente    FORMAT A12  HEAD "Attente max"
COL objet      FORMAT A22  HEAD "Objet en conflit"
COL verdict    FORMAT A44  HEAD "Verdict"

SELECT b.sid || ' - ' || NVL(SUBSTR(b.username, 1, 18), 'SANS NOM') AS bloquant
      ,SUBSTR(NVL(b.module, b.machine), 1, 24)                      AS provenance
      -- DISTINCT : la jointure sur DBA_OBJECTS ne doit pas gonfler le compteur
      ,COUNT(DISTINCT w.sid)                                        AS nb_bloq
      ,LPAD(CASE WHEN MAX(w.seconds_in_wait) >= 3600
                 THEN TRIM(TO_CHAR(ROUND(MAX(w.seconds_in_wait)/3600, 1), '990.0')) || ' h'
                 ELSE TRIM(TO_CHAR(ROUND(MAX(w.seconds_in_wait)/60), '9,999')) || ' min'
            END, 12)                                                AS attente
      ,SUBSTR(NVL(MIN(o.object_name), '-'), 1, 22)                  AS objet
      ,CASE
            -- Le cas le plus frequent en production : un COMMIT oublie.
            WHEN b.status = 'INACTIVE' AND b.last_call_et > 3600
            THEN '!! Inactive depuis '
                 || TRIM(TO_CHAR(ROUND(b.last_call_et/3600, 1), '990.0'))
                 || ' h : COMMIT oublie'
            WHEN b.status = 'INACTIVE'
            THEN '!! Transaction ouverte, session au repos'
            WHEN MAX(w.seconds_in_wait) >= 600
            THEN 'Traitement long, duree habituelle a verifier'
            ELSE 'Traitement en cours, attente normale'
       END                                                          AS verdict
  FROM v$session w
  JOIN v$session b
    ON b.sid = w.blocking_session
  LEFT JOIN dba_objects o
    ON o.object_id = w.row_wait_obj#
   AND w.row_wait_obj# > 0
 WHERE w.blocking_session IS NOT NULL
   AND w.blocking_session_status IN ('VALID', 'GLOBAL')
   AND NVL(w.blocking_instance, TO_NUMBER(SYS_CONTEXT('USERENV', 'INSTANCE')))
       = TO_NUMBER(SYS_CONTEXT('USERENV', 'INSTANCE'))
 GROUP BY b.sid, b.username, b.module, b.machine, b.status, b.last_call_et
UNION ALL
-- Une section vide est un resultat, pas un doute sur l'execution du script :
-- SET FEEDBACK OFF supprime aussi le "no rows selected".
SELECT 'Aucune', '-', 0, LPAD('-', 12), '-'
      ,'Aucune session n''en bloque une autre'
  FROM dual
 WHERE NOT EXISTS (SELECT 1 FROM v$session
                    WHERE blocking_session IS NOT NULL
                      AND blocking_session_status IN ('VALID', 'GLOBAL')
                      AND NVL(blocking_instance,
                              TO_NUMBER(SYS_CONTEXT('USERENV', 'INSTANCE')))
                          = TO_NUMBER(SYS_CONTEXT('USERENV', 'INSTANCE')))
 ORDER BY 3 DESC
;

PROMPT
PROMPT  Requetes actives depuis plus de 10 minutes (10 premieres) :
PROMPT

-- -----------------------------------------------
-- 3. Traitements longs en cours
-- -----------------------------------------------

COL sid_serial FORMAT A14  HEAD "SID,Serial"
COL compte     FORMAT A18  HEAD "Compte"
COL origine    FORMAT A26  HEAD "Origine"
COL duree      FORMAT A12  HEAD "En cours"
COL evenement  FORMAT A30  HEAD "Attend sur"
COL requete    FORMAT A40  HEAD "Debut de la requete"

SELECT t.sid_serial                                               AS sid_serial
      ,t.compte                                                   AS compte
      ,t.origine                                                  AS origine
      ,t.duree                                                    AS duree
      ,t.evenement                                                AS evenement
      ,t.requete                                                  AS requete
  FROM (
    SELECT s.sid || ',' || s.serial#                              AS sid_serial
          ,SUBSTR(NVL(s.username, '-'), 1, 18)                    AS compte
          ,SUBSTR(NVL(s.module, s.machine), 1, 26)                AS origine
          ,LPAD(CASE WHEN s.last_call_et >= 3600
                     THEN TRIM(TO_CHAR(ROUND(s.last_call_et/3600, 1), '990.0')) || ' h'
                     ELSE TRIM(TO_CHAR(ROUND(s.last_call_et/60), '9,999')) || ' min'
                END, 12)                                          AS duree
          ,SUBSTR(s.event, 1, 30)                                 AS evenement
          -- Sous-requete scalaire plutot qu'une jointure : garantit une
          -- seule ligne par session, quel que soit le contenu du cache.
          ,NVL((SELECT SUBSTR(REGEXP_REPLACE(q.sql_text, '[[:space:]]+', ' '), 1, 40)
                  FROM v$sqlarea q
                 WHERE q.sql_id = s.sql_id
                   AND ROWNUM = 1), '-')                          AS requete
      FROM v$session s
     WHERE s.type = 'USER'
       AND s.status = 'ACTIVE'
       AND s.last_call_et > 600
     ORDER BY s.last_call_et DESC
  ) t
 WHERE ROWNUM <= 10
UNION ALL
SELECT '-', '-', '-', LPAD('-', 12), '-'
      ,'Aucune requete active depuis 10 min'
  FROM dual
 WHERE NOT EXISTS (SELECT 1 FROM v$session
                    WHERE type = 'USER'
                      AND status = 'ACTIVE'
                      AND last_call_et > 600)
;

PROMPT
PROMPT ========================== COMMENT LIRE ==========================
PROMPT
PROMPT  Un bloquant INACTIVE est une transaction non validee : la session
PROMPT  ne travaille plus, mais elle detient toujours ses verrous. Elle ne
PROMPT  les rendra qu'au COMMIT, au ROLLBACK ou a la deconnexion.
PROMPT
PROMPT  Un bloquant ACTIVE fait son travail. Avant de le tuer, se rappeler
PROMPT  que le ROLLBACK peut prendre autant de temps que la transaction
PROMPT  elle-meme, parfois davantage : les verrous ne tomberont qu'apres.
PROMPT
PROMPT  Descendre au detail d'une session :
PROMPT    SELECT * FROM v$session WHERE sid = <sid>
PROMPT    SELECT * FROM v$lock    WHERE sid = <sid>
PROMPT
PROMPT ==================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_12
