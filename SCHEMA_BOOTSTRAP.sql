------------------------------------------------------------------------------
-- SCHEMA_BOOTSTRAP.sql
--
-- Zweck : Administrative Rahmenbedingungen fuer ein neues Schema herstellen,
--         BEVOR die fachliche DDL (Tabellen, Constraints, ...) beginnt.
--
-- Reihenfolge im Toolkit:
--   1. USER_ADMIN.CREATE_USER(...)   -> Schema/User existiert
--   2. SCHEMA_BOOTSTRAP.sql          -> DIESES SKRIPT
--   3. Fachliche DDL fuer das neue Schema
--
-- Ausfuehrung : SYS AS SYSDBA, in der Ziel-PDB (PDBORCL)
-- Client      : Oracle SQL Developer 24.3.1 -> mit F5 (Run Script) starten,
--               NICHT mit Strg+Enter (Skript enthaelt mehrere PL/SQL-Bloecke)
-- Wiederholbar: Ja - alle Schritte sind so gebaut, dass ein erneuter Lauf
--               (z. B. nach Nachbesserung der Parameter) nicht fehlschlaegt.
------------------------------------------------------------------------------

ALTER SESSION SET CONTAINER = PDBORCL;

------------------------------------------------------------------------------
-- Parameter (vor Ausfuehrung anpassen bzw. bei Aufruf per Script abfragen)
------------------------------------------------------------------------------
DEFINE schema_name   = 'USER1'
DEFINE default_tbs   = 'USERS'
DEFINE temp_tbs      = 'TEMP'
DEFINE quota_mb      = '500'
DEFINE restore_point = 'RP_BOOTSTRAP_&schema_name'

PROMPT ==============================================================
PROMPT  Bootstrap fuer Schema: &schema_name
PROMPT ==============================================================

------------------------------------------------------------------------------
-- 0) Container-Guard - Skript bricht ab, wenn falscher Container aktiv ist
------------------------------------------------------------------------------
DECLARE
    v_con VARCHAR2(30);
BEGIN
    SELECT SYS_CONTEXT('USERENV','CON_NAME') INTO v_con FROM DUAL;
    IF v_con != 'PDBORCL' THEN
        RAISE_APPLICATION_ERROR(-20001,
            'Falscher Container: ' || v_con || ' - bitte zuerst ALTER SESSION SET CONTAINER = PDBORCL;');
    END IF;
END;
/

------------------------------------------------------------------------------
-- 1) Tablespace-Zuordnung & Quota
--    Verhindert, dass das Schema unbemerkt im Default-Tablespace USERS
--    landet und/oder unbegrenzt Platz verbrauchen kann.
------------------------------------------------------------------------------
ALTER USER &schema_name DEFAULT TABLESPACE &default_tbs;
ALTER USER &schema_name TEMPORARY TABLESPACE &temp_tbs;
ALTER USER &schema_name QUOTA &quota_mb M ON &default_tbs;

------------------------------------------------------------------------------
-- 2) Rollen statt Einzel-Grants
--    DB_CONNECT buendelt bereits CONNECT/RESOURCE/CREATE SESSION etc.
--    Zusaetzliche fachliche Rechte gehoeren in eine eigene Rolle, nicht
--    als Einzel-GRANT direkt an den User.
------------------------------------------------------------------------------
GRANT DB_CONNECT TO &schema_name;

-- Beispiel-Vorlage fuer eine zusaetzliche fachliche Rolle (bei Bedarf):
-- CREATE ROLE &schema_name._APP_ROLE;
-- GRANT &schema_name._APP_ROLE TO &schema_name;

------------------------------------------------------------------------------
-- 3) Passwort-Profil
--    Idempotent: falls USER_ADMIN.CREATE_USER das Profil schon gesetzt hat,
--    ist dies ein No-Op.
------------------------------------------------------------------------------
ALTER USER &schema_name PROFILE USER_ADMIN_PROFILE;

------------------------------------------------------------------------------
-- 4) NLS-Konsistenz
--    AFTER-LOGON-Trigger auf Schema-Ebene setzt NLS_LENGTH_SEMANTICS fuer
--    jede Session dieses Users automatisch - relevant, sobald VARCHAR2-
--    Spalten mit Umlauten/Sonderzeichen befuellt werden.
------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER &schema_name..trg_session_nls
AFTER LOGON ON &schema_name..SCHEMA
BEGIN
    EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LENGTH_SEMANTICS = CHAR';
END;
/

------------------------------------------------------------------------------
-- 5) Unified Auditing
--    Stellt sicher, dass DDL-Aktionen dieses Users von ADMIN_DDL_POLICY
--    erfasst werden. Falls die Policy bereits fuer ALL USERS aktiv ist,
--    ist dieser Schritt redundant, aber ungefaehrlich.
------------------------------------------------------------------------------
AUDIT POLICY ADMIN_DDL_POLICY BY &schema_name;

------------------------------------------------------------------------------
-- 6) Guaranteed Restore Point vor dem DDL-Batch
--    Schnellstes Rollback-Netz fuer die erste Migration.
--    WICHTIG: Nach erfolgreicher DDL wieder droppen (siehe Punkt 8),
--    sonst laeuft die Fast Recovery Area voll.
------------------------------------------------------------------------------
CREATE RESTORE POINT &restore_point GUARANTEE FLASHBACK DATABASE;

------------------------------------------------------------------------------
-- 7) Kontrolle
------------------------------------------------------------------------------
COLUMN username              FOR A20
COLUMN default_tablespace    FOR A20
COLUMN temporary_tablespace  FOR A20
COLUMN profile               FOR A25
COLUMN account_status        FOR A20

SELECT username, default_tablespace, temporary_tablespace, profile, account_status
FROM   dba_users
WHERE  username = UPPER('&schema_name');

SELECT username, tablespace_name, max_bytes
FROM   dba_ts_quotas
WHERE  username = UPPER('&schema_name');

SELECT name, scn, time, guarantee_flashback_database
FROM   v$restore_point
WHERE  name = UPPER('&restore_point');

PROMPT ==============================================================
PROMPT  Bootstrap fuer &schema_name abgeschlossen.
PROMPT  Schema ist bereit fuer die fachliche DDL.
PROMPT
PROMPT  Nach erfolgreicher DDL-Migration nicht vergessen:
PROMPT  DROP RESTORE POINT &restore_point;
PROMPT ==============================================================
