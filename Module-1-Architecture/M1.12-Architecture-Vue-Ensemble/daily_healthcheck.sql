-- ============================================================================
-- SCRIPT     : daily_healthcheck.sql
-- MODULE     : M1.12 - Architecture Oracle, vue d'ensemble
-- AUTEUR     : Omar SALL - DBSentinel Academy
-- VERSION    : Oracle 12c, 18c, 19c, 21c, 23ai
-- ============================================================================
-- USAGE      : SQL> @daily_healthcheck.sql
-- ============================================================================
-- OBJET      : Les 5 controles du matin en une seule execution.
--              Chaque ligne renvoie vers le script du module concerne :
--              ce script dit QU'IL Y A un probleme, pas comment le resoudre.
--
-- PORTEE     : l'alert.log lu est celui de l'INSTANCE courante. En RAC,
--              relancer le script sur chaque noeud. En CDB, l'espace et
--              l'alert.log ne couvrent que le conteneur courant, et les
--              sauvegardes RMAN ne sont visibles que depuis CDB$ROOT.
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ================ CHECK-UP QUOTIDIEN - LES 5 CONTROLES ================
PROMPT

-- -----------------------------------------------
-- 1. Les 5 controles, une ligne chacun
-- -----------------------------------------------

COL controle FORMAT A26  HEAD "Controle"
COL resultat FORMAT A56  HEAD "Resultat"
COL renvoi   FORMAT A32  HEAD "Si alerte, lancer"

-- Check 1 : erreurs remontees dans l'alert.log sur 24 h.
-- Deux precautions indispensables pour que ce controle reste lisible :
--   - l'alert.log ecrit les codes SANS zeros de tete ("ORA-1652" et non
--     "ORA-01652") : la regex accepte 1 a 5 chiffres, sinon les erreurs
--     d'espace les plus frequentes seraient ignorees en silence ;
--   - les messages benins (deconnexion client, changement de redo, Data
--     Guard) sont exclus, sans quoi le controle serait rouge chaque matin
--     sur une base saine et plus personne ne le lirait.
SELECT '1. Alert.log (24h)'                                       AS controle
      ,CASE
            WHEN e.graves > 0
            THEN '!! CRITIQUE : erreur interne ou corruption de bloc'
            WHEN e.total = 0
            THEN 'OK : aucune erreur ORA sur les 24 dernieres heures'
            ELSE '!! ' || TRIM(TO_CHAR(e.total, '999,999'))
                 || ' erreur(s) ORA - voir le detail plus bas'
       END                                                        AS resultat
      ,'@check_alertlog.sql    (M1.3)'                            AS renvoi
  FROM (SELECT COUNT(*) AS total
              ,SUM(CASE WHEN REGEXP_LIKE(message_text,
                     'ORA-0*(600|7445|1578)[^0-9]') THEN 1 ELSE 0 END) AS graves
          FROM v$diag_alert_ext
         WHERE originating_timestamp > SYSTIMESTAMP - INTERVAL '1' DAY
           AND REGEXP_LIKE(message_text, 'ORA-[0-9]')
           AND NOT REGEXP_LIKE(message_text,
                 'ORA-0*(609|1013|279|280|312|16401|16143|1109|3136)[^0-9]')
       ) e
UNION ALL
-- Check 2 : espace. Le taux retenu est le seul mur certain cote Oracle :
-- occupe / plafond, le plafond etant le MAXSIZE ou, a defaut, la limite
-- physique du datafile. Un fort taux d'occupation de l'espace ALLOUE n'est
-- pas retenu : avec autoextend c'est le regime normal, et en alerter chaque
-- matin ferait ignorer les vraies alertes.
-- UNDO exclu : ses extents expires restent alloues et sont recycles en
-- interne, donc DBA_FREE_SPACE le montre en permanence proche de 100%.
-- TEMP exclu de meme (voir M1.9 et M1.10 pour leur dimensionnement).
SELECT '2. Espace tablespaces'
      ,CASE
            WHEN t.pire_pct IS NULL
            THEN 'Aucun tablespace permanent a mesurer'
            WHEN t.pire_pct >= 95
            THEN '!! CRITIQUE : ' || t.pire_ts || ' a '
                 || TRIM(TO_CHAR(t.pire_pct, '990.0')) || '% du plafond'
            WHEN t.pire_pct >= 85
            THEN '!! ' || t.pire_ts || ' a '
                 || TRIM(TO_CHAR(t.pire_pct, '990.0')) || '% du plafond'
            ELSE 'OK : plus fort taux ' || t.pire_ts || ' a '
                 || TRIM(TO_CHAR(t.pire_pct, '990.0')) || '%'
       END
      ,'@check_tablespaces.sql (M1.6)'
  FROM (
    SELECT MAX(x.risque)                                          AS pire_pct
          ,MAX(SUBSTR(x.ts, 1, 18)) KEEP (DENSE_RANK LAST
             ORDER BY x.risque)                                   AS pire_ts
      FROM (
        SELECT df.tablespace_name                                 AS ts
              ,(SUM(df.bytes) - NVL(MAX(fr.libre), 0)) * 100
               / NULLIF(SUM(CASE WHEN df.autoextensible = 'YES'
                                 THEN GREATEST(df.maxbytes, df.bytes)
                                 ELSE df.bytes END), 0)           AS risque
          FROM dba_data_files df
          JOIN dba_tablespaces ts
            ON ts.tablespace_name = df.tablespace_name
          LEFT JOIN (SELECT tablespace_name, SUM(bytes) AS libre
                       FROM dba_free_space
                      GROUP BY tablespace_name) fr
            ON fr.tablespace_name = df.tablespace_name
         -- Un tablespace hors ligne n'apparait pas dans DBA_FREE_SPACE :
         -- le garder afficherait 100% d'occupation par construction.
         WHERE ts.contents = 'PERMANENT'
           AND ts.status = 'ONLINE'
         GROUP BY df.tablespace_name
      ) x
  ) t
UNION ALL
-- Check 3 : zone d'archivage. Une FRA saturee bloque RMAN et le flashback
-- meme en NOARCHIVELOG : le mode d'archivage ne sert qu'a nuancer le message,
-- jamais a sauter le controle.
-- Le CROSS JOIN evite ORA-00937 : un agregat et une sous-requete scalaire
-- ne peuvent pas coexister dans un SELECT sans GROUP BY.
SELECT '3. Zone d''archivage'
      ,CASE
            WHEN NVL(f.taille, 0) = 0 AND d.log_mode <> 'ARCHIVELOG'
            THEN 'NOARCHIVELOG et aucune FRA : rien a surveiller'
            WHEN NVL(f.taille, 0) = 0
            THEN 'FRA non configuree : verifier LOG_ARCHIVE_DEST_n'
            WHEN f.occupe * 100 / f.taille >= 85
            THEN '!! FRA a '
                 || TRIM(TO_CHAR(f.occupe * 100 / f.taille, '990.0'))
                 || '% : RMAN et l''archivage se bloqueront'
            ELSE 'OK : FRA a '
                 || TRIM(TO_CHAR(f.occupe * 100 / f.taille, '990.0'))
                 || '% (espace recuperable deduit)'
       END
      ,'@v_fra_usage.sql       (M1.7)'
  FROM (SELECT SUM(space_limit)                        AS taille
              ,SUM(space_used - space_reclaimable)     AS occupe
          FROM v$recovery_file_dest) f
 CROSS JOIN v$database d
UNION ALL
-- Check 4 : sessions bloquees. Une chaine de blocage ne se voit pas
-- dans les temps de reponse moyens, elle se voit ici.
SELECT '4. Sessions bloquees'
      ,CASE
            WHEN COUNT(*) = 0
            THEN 'OK : aucune session en attente d''une autre'
            WHEN MAX(seconds_in_wait) >= 600
            THEN '!! ' || TRIM(TO_CHAR(COUNT(*), '999,999'))
                 || ' bloquee(s), la plus ancienne depuis '
                 || TRIM(TO_CHAR(ROUND(MAX(seconds_in_wait)/60), '999,999'))
                 || ' min'
            ELSE TRIM(TO_CHAR(COUNT(*), '999,999'))
                 || ' session(s) bloquee(s) depuis moins de 10 min'
       END
      ,'@v_sessions_locks.sql  (M1.12)'
  FROM v$session
 WHERE blocking_session IS NOT NULL
   -- 'GLOBAL' signale un bloqueur situe sur une autre instance RAC
   AND blocking_session_status IN ('VALID', 'GLOBAL')
UNION ALL
-- Check 5 : sauvegarde. Lu dans le control file, dont CONTROL_FILE_RECORD_
-- KEEP_TIME (7 jours par defaut) garantit la retention MINIMALE.
-- Seul un statut COMPLETED strict vaut succes : "COMPLETED WITH ERRORS" est
-- un echec partiel, et l'afficher en OK serait le pire faux negatif possible.
-- Filtre sur les sauvegardes de donnees : un backup d'archivelogs seul ne
-- rend pas la base restaurable. Les sauvegardes tablespace par tablespace
-- ou datafile par datafile comptent aussi (INPUT_TYPE = 'DATAFILE ...').
SELECT '5. Derniere sauvegarde'
      ,CASE
            WHEN SYS_CONTEXT('USERENV', 'CON_ID') > 2
            THEN 'A lancer depuis CDB$ROOT : jobs RMAN non visibles ici'
            WHEN b.derniere IS NULL AND b.en_erreur IS NULL
            THEN '!! Aucune sauvegarde de donnees tracee'
            WHEN b.derniere IS NULL
            THEN '!! Derniere tentative en ERREUR le '
                 || TO_CHAR(b.en_erreur, 'DD/MM/YYYY HH24:MI')
            WHEN b.derniere < SYSDATE - 1
            THEN '!! Derniere sauvegarde il y a '
                 || TRIM(TO_CHAR(ROUND(SYSDATE - b.derniere, 1), '990.0'))
                 || ' jours'
            ELSE 'OK : ' || TO_CHAR(b.derniere, 'DD/MM/YYYY HH24:MI')
                 || ' (il y a '
                 || TRIM(TO_CHAR(ROUND((SYSDATE - b.derniere) * 24, 1), '990.0'))
                 || ' h)'
       END
      ,'RMAN> LIST BACKUP SUMMARY'
  FROM (SELECT MAX(CASE WHEN status = 'COMPLETED' THEN end_time END)
                                                                  AS derniere
              ,MAX(CASE WHEN status <> 'COMPLETED' THEN end_time END)
                                                                  AS en_erreur
          FROM v$rman_backup_job_details
         WHERE input_type IN ('DB FULL', 'DB INCR', 'RECVR AREA'
                             ,'DATAFILE FULL', 'DATAFILE INCR')) b
;

PROMPT
PROMPT  Detail des erreurs ORA des 24 dernieres heures (une ligne par code) :
PROMPT

-- -----------------------------------------------
-- 2. Erreurs ORA agregees par code
--    Une ligne par code, jamais une ligne par occurrence : un ORA-01555
--    survenu 400 fois reste une seule ligne, avec son compteur.
--    Les codes sont normalises sur 5 chiffres : l'alert.log ecrit
--    indifferemment "ORA-1652" et "ORA-01652".
-- -----------------------------------------------

COL code_ora    FORMAT A12  HEAD "Code"
COL occurrences FORMAT 999,999 HEAD "Nb"
COL premiere    FORMAT A17  HEAD "Premiere"
COL derniere    FORMAT A17  HEAD "Derniere"
COL signification FORMAT A44 HEAD "Signification"
COL gravite     FORMAT A22  HEAD "Gravite"

SELECT e.code_ora                                                 AS code_ora
      ,COUNT(*)                                                   AS occurrences
      ,TO_CHAR(MIN(e.horodatage), 'DD/MM HH24:MI:SS')             AS premiere
      ,TO_CHAR(MAX(e.horodatage), 'DD/MM HH24:MI:SS')             AS derniere
      ,CASE e.code_ora
            WHEN 'ORA-00600' THEN 'Erreur interne Oracle : ouvrir un SR'
            WHEN 'ORA-07445' THEN 'Crash d''un processus : ouvrir un SR'
            WHEN 'ORA-01578' THEN 'Bloc corrompu : RMAN VALIDATE immediat'
            WHEN 'ORA-00060' THEN 'Deadlock : deux sessions s''attendent'
            WHEN 'ORA-01555' THEN 'UNDO recycle trop vite'
            WHEN 'ORA-01652' THEN 'Segment temporaire : tablespace sature'
            WHEN 'ORA-01653' THEN 'Tablespace plein : extension impossible'
            WHEN 'ORA-30036' THEN 'UNDO plein : l''instruction echoue'
            WHEN 'ORA-04031' THEN 'Memoire SGA : allocation refusee'
            WHEN 'ORA-04030' THEN 'PGA insuffisante pour la session'
            WHEN 'ORA-00257' THEN 'Archivage bloque : plus de transaction'
            WHEN 'ORA-00028' THEN 'Session tuee par ALTER SYSTEM KILL'
            WHEN 'ORA-12012' THEN 'Job planifie en erreur (DBMS_SCHEDULER)'
            WHEN 'ORA-01031' THEN 'Privileges insuffisants sur une operation'
            WHEN 'ORA-00054' THEN 'Ressource occupee : verrou non obtenu'
            ELSE 'Consulter la documentation Oracle'
       END                                                        AS signification
      ,CASE
            WHEN e.code_ora IN ('ORA-00600', 'ORA-07445', 'ORA-01578', 'ORA-00257')
            THEN '!! CRITIQUE'
            WHEN e.code_ora IN ('ORA-04031', 'ORA-30036', 'ORA-01652', 'ORA-01653')
            THEN '!! Production impactee'
            ELSE 'A analyser'
       END                                                        AS gravite
  FROM (
    -- LPAD sur le groupe capture : "ORA-1652" et "ORA-01652" designent la
    -- meme erreur et doivent etre comptes ensemble.
    SELECT 'ORA-' || LPAD(REGEXP_SUBSTR(message_text,
              'ORA-0*([0-9]{1,5})', 1, 1, NULL, 1), 5, '0')       AS code_ora
          ,originating_timestamp                                  AS horodatage
      FROM v$diag_alert_ext
     WHERE originating_timestamp > SYSTIMESTAMP - INTERVAL '1' DAY
       AND REGEXP_LIKE(message_text, 'ORA-[0-9]')
       AND NOT REGEXP_LIKE(message_text,
             'ORA-0*(609|1013|279|280|312|16401|16143|1109|3136)[^0-9]')
  ) e
 WHERE e.code_ora IS NOT NULL
 GROUP BY e.code_ora
 ORDER BY CASE
               WHEN e.code_ora IN ('ORA-00600', 'ORA-07445', 'ORA-01578', 'ORA-00257')
               THEN 1
               ELSE 2
          END
         ,COUNT(*) DESC
;

PROMPT
PROMPT ========================= SEUILS APPLIQUES =========================
PROMPT
PROMPT  Alert.log           : messages benins exclus (ORA-609 deconnexion
PROMPT                        client, ORA-279/280/312 redo, Data Guard)
PROMPT  Espace tablespaces  : alerte a 85% du PLAFOND (MAXSIZE, ou limite
PROMPT                        physique du datafile), pas de l'espace alloue :
PROMPT                        avec autoextend, un fort taux d'occupation de
PROMPT                        l'alloue est le regime normal. UNDO et TEMP
PROMPT                        exclus, ils recyclent leurs extents : M1.10, M1.9
PROMPT  Zone d'archivage    : alerte a 85%, espace recuperable deduit
PROMPT  Sessions bloquees   : alerte au-dela de 10 minutes d'attente
PROMPT  Sauvegarde          : alerte au-dela de 24 heures. Seul le statut
PROMPT                        COMPLETED vaut succes, pas COMPLETED WITH ERRORS
PROMPT
PROMPT  Aucune vue sous option Oracle n'est interrogee ici : ce script
PROMPT  fonctionne sans Diagnostics Pack ni Tuning Pack.
PROMPT
PROMPT ====================================================================

SET FEEDBACK ON
CLEAR COLUMNS

-- DBSentinel Academy - #DBSA_M1_12
