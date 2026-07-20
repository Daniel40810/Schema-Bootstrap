# Oracle DBA Toolkit – User-Verwaltung & Administration (Oracle 21c)

[![Oracle](https://img.shields.io/badge/Oracle-Database%2021c-F80000?logo=oracle&logoColor=white)](https://www.oracle.com/database/)
[![SQL](https://img.shields.io/badge/Language-PL%2FSQL-FF0000?logo=oracle&logoColor=white)](https://docs.oracle.com/en/database/oracle/oracle-database/21/sqlrf/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Production-brightgreen)](https://github.com/)

Ein modulares, produktionsreifes Set aus **PL/SQL-Packages**, **Scheduler-Jobs** und **Konfigurations-Runbooks** zur Vereinfachung der täglichen Datenbank-Administration auf **Oracle Database 21c** in einer Multitenant-Umgebung (PDB `PDBORCL`).

---

## 📋 Features

- ✅ **Zentrale User-Verwaltung** – CREATE/DROP/RESET/LOCK über konsistentes PL/SQL-Package mit durchgängigem Logging
- ✅ **Schema-Bootstrap** – Administrative Rahmenbedingungen für neue Schemas (Tablespace, Quota, Rollen, Profile, Auditing, Restore Point)
- ✅ **Passwort-Policy** – Zentrales Profil mit Komplexität, Ablauf, Sperren nach Fehlversuchen
- ✅ **Automated Health Checks** – Tägl. Tablespace-Auslastung, invalide Objekte, fehlgeschlagene Jobs, Alert-Log-Fehler
- ✅ **Unified Auditing** – DDL-/Privilegs-/Logins-Auditing + Auto-Purge
- ✅ **Flashback-Fallback** – PDB-Level Flashback für schnelles Rollback nach Fehlern
- ✅ **Netzwerk-Härtung** – listener.ora, sqlnet.ora, DB-Sicherheitsparameter
- ✅ **Idempotent & Wiederholbar** – Alle Skripte können mehrfach hintereinander ausgeführt werden

---

## 🚀 Schnelleinstieg

### Voraussetzungen

| Anforderung | Details |
|---|---|
| **Datenbank** | Oracle Database 21c |
| **Architektur** | Multitenant (CDB `ORCL`, Ziel-PDB: `PDBORCL`) |
| **Rechte** | Ausführung als `SYS AS SYSDBA` |
| **Client** | Oracle SQL Developer 24.3.1 (empfohlen) oder SQL*Plus |

### Installation (5 Minuten)

```sql
-- 1. Container wechseln
ALTER SESSION SET CONTAINER = PDBORCL;

-- 2. Alle Skripte mit F5 (Run Script) in SQL Developer ausführen:
@DB_CONNECT.sql
@USER_ADMIN_PACKAGE.sql
@USER_ADMIN_PROFILE_SCHEDULER.sql
@DBA_HEALTH_CHECK.sql
@UNIFIED_AUDIT_POLICY.sql
@NETWORK_LISTENER_HARDENING.sql

-- 3. Optional: Flashback & EM Express (deprecated)
@FLASHBACK_DATABASE_SETUP.sql
@EM_EXPRESS_SETUP.sql
```

**Danach:** Neuen User + Schema mit Bootstrap vorbereiten:

```sql
-- User anlegen
EXEC USER_ADMIN.CREATE_USER('APP_USER', 'ComplexPwd123!');

-- Schema admin. vorbereiten (Tablespace, Quota, Rollen, Restore Point)
@SCHEMA_BOOTSTRAP.sql
-- (Parameter anpassen: schema_name = 'APP_USER', etc.)

-- Fachliche DDL durchführen
@app_user_ddl.sql

-- Bootstrap-Restore-Point nach erfolgreicher DDL droppen
DROP RESTORE POINT RP_BOOTSTRAP_APP_USER;
```

---

## 📁 Projektstruktur

```
.
├── README.md                         # ← Du bist hier
├── LICENSE                           # MIT oder nach Bedarf
├── docs/
│   └── USER_ADMIN_Dokumentation.md   # Ausführliche Detail-Doku
│   └── SCHEMA_BOOTSTRAP.md           # Schema-Bootstrap erklärt
│
├── sql/
│   ├── 1_DB_CONNECT.sql              # Rolle mit Basis-Rechten
│   ├── 2_USER_ADMIN_PACKAGE.sql      # Package + Log-Tabelle
│   ├── 3_USER_ADMIN_PROFILE_SCHEDULER.sql  # Profil + Jobs
│   ├── 4_DBA_HEALTH_CHECK.sql        # Health-Check + Job
│   ├── 5_UNIFIED_AUDIT_POLICY.sql    # Audit-Policies + Job
│   ├── 6_NETWORK_LISTENER_HARDENING.sql  # Netzwerk-Sicherheit
│   ├── 7_FLASHBACK_DATABASE_SETUP.sql    # Flashback (optional)
│   ├── 8_EM_EXPRESS_SETUP.sql            # EM Express (optional, deprecated)
│   └── schema/
│       ├── SCHEMA_BOOTSTRAP.sql      # Für jedes neue Schema
│       └── SCHEMA_SEQUENCE_TEMPLATE.sql (geplant)
│
└── examples/
    ├── user_admin_usage.sql          # Allgemeines User-Workflow
    └── schema_bootstrap_workflow.sql # Schema-Setup-Workflow
```

---

## 🔧 Komponenten im Überblick

### 1. Rolle `DB_CONNECT` (`DB_CONNECT.sql`)
Bündelt Grundrechte für jeden neuen User:
- `CONNECT`, `RESOURCE`
- `CREATE SESSION`, `CREATE TABLE`, `CREATE SEQUENCE`, `CREATE PROCEDURE`
- `CREATE JOB` für selbstständige Scheduler-Tasks

### 2. Package `USER_ADMIN` (`USER_ADMIN_PACKAGE.sql`)
Zentrale, protokollierte User-Verwaltung mit CRUD-Operationen:

```sql
EXEC USER_ADMIN.CREATE_USER('APP_USER', 'Passwort123!');
EXEC USER_ADMIN.RESET_PASSWORD('APP_USER', 'NeuesPwd!');
EXEC USER_ADMIN.LOCK_USER('APP_USER');
EXEC USER_ADMIN.DROP_USER('APP_USER');
EXEC USER_ADMIN.LIST_USERS;
```

Alle Aktionen schreiben in `USER_ADMIN_LOG` (autonome Transaktion → Log bleibt auch bei Rollback erhalten).

### 3. Schema Bootstrap (`SCHEMA_BOOTSTRAP.sql`)
Bereitet ein neues Schema administrativ vor:

| # | Schritt | Zweck |
|---|---|---|
| 0 | Container-Guard | Bricht ab, falls falscher Container |
| 1 | Tablespace & Quota | Default-TBS, Temp-TBS, begrenzte Quota |
| 2 | Rollen | `DB_CONNECT` zuweisen (statt Einzel-Grants) |
| 3 | Passwort-Profil | `USER_ADMIN_PROFILE` erzwingt Komplexität |
| 4 | NLS-Konsistenz | AFTER-LOGON-Trigger setzt `NLS_LENGTH_SEMANTICS` |
| 5 | Auditing | Schema in `ADMIN_DDL_POLICY` aufnehmen |
| 6 | Restore Point | Guaranteed Restore Point für Rollback-Netz |
| 7 | Kontrolle | Verifikation aller Parameter |

### 4. Passwort-Profil & Scheduler (`USER_ADMIN_PROFILE_SCHEDULER.sql`)
- Profil `USER_ADMIN_PROFILE` mit Komplexität, Ablauf (90 Tage), Sperren
- Scheduler-Jobs für automatisierte Wartung:
  - **`JOB_LOCK_INACTIVE_USERS`** – tägl. 02:00 – sperrt User ohne Login seit N Tagen
  - **`JOB_PURGE_USER_ADMIN_LOG`** – mtl. 1., 03:00 – alte Log-Einträge entfernen

### 5. Health-Check Package (`DBA_HEALTH_CHECK.sql`)
Tägl. automatisierter Gesundheitscheck:

```sql
EXEC DBA_HEALTH_CHECK.RUN_ALL;
SELECT * FROM DBA_HEALTH_CHECK_LOG 
WHERE STATUS IN ('WARNING','CRITICAL','ERROR') 
AND CHECK_DATE > TRUNC(SYSDATE);
```

Prüft: Tablespace-Auslastung, invalide Objekte, fehlgeschlagene Jobs, Alert-Log-Fehler.

### 6. Unified Auditing (`UNIFIED_AUDIT_POLICY.sql`)
- **`ADMIN_DDL_POLICY`** – User-/Rechtsverwaltung (CREATE/ALTER/DROP USER/ROLE/GRANT)
- **`PRIVILEGED_LOGON_POLICY`** – SYSDBA/SYSOPER Logins
- **`USER_ADMIN_OBJECT_POLICY`** – Schutz der Log-Tabellen selbst

Auto-Purge tägl. 01:00 → `UNIFIED_AUDIT_TRAIL_PURGE_JOB`.

### 7. Netzwerk-Härtung (`NETWORK_LISTENER_HARDENING.sql`)
- **listener.ora** – `ADMIN_RESTRICTIONS_LISTENER`, Valid Node Checking
- **sqlnet.ora** – Native Encryption, Protocol Filtering
- **DB-Parameter** – `SEC_MAX_FAILED_LOGIN_ATTEMPTS`, `SEC_PROTOCOL_ERROR_TRACE_ACTION`

### 8. Flashback (optional) (`FLASHBACK_DATABASE_SETUP.sql`)
PDB-Level Flashback-Schutz (schnelles Rollback nach Fehler).  
⚠️ Braucht ARCHIVELOG + LOCAL UNDO; nach Restore Point dropppen, um Fast Recovery Area nicht zu füllen.

---

## 📚 Dokumentation

| Datei | Beschreibung |
|---|---|
| **[USER_ADMIN_Dokumentation.md](docs/USER_ADMIN_Dokumentation.md)** | Ausführliche Referenz aller Packages, Parameter, Beispiele, SQL-Developer-Tipps |
| **[SCHEMA_BOOTSTRAP.md](docs/SCHEMA_BOOTSTRAP.md)** | Schema-Bootstrap erklärt – wann/wie/warum |

---

## 📖 Typischer Workflow

```
1. Toolkit installieren (6 SQL-Dateien, ~20 Minuten)
   ↓
2. USER_ADMIN.CREATE_USER('MYAPP', 'Pwd!')
   ↓
3. SCHEMA_BOOTSTRAP.sql (setzt Container, Tablespace, Quota, Rollen, Audit, Restore Point)
   ↓
4. Eigene DDL-Skripte (Tabellen, Constraints, Sequences, Trigger)
   ↓
5. DBA_HEALTH_CHECK.RUN_ALL (Validierung)
   ↓
6. DROP RESTORE POINT RP_BOOTSTRAP_MYAPP; (Cleanup nach Erfolg)
```

---

## 🔐 Sicherheitshinweise

- **Passwörter**: Werden aktuell als Klartext-Parameter übergeben; für Produktion ggf. `DBMS_CRYPTO` verwenden.
- **Restore Points**: Sind kein Backup-Ersatz. Nach erfolgreicher DDL-Migration wieder droppen, sonst läuft die Fast Recovery Area voll.
- **Valid Node Checking**: Kann aussperren – immer `127.0.0.1` + Admin-Rechner testen.
- **EM Express**: Deprecated ab Oracle 21c → SQL Developer Web / ORDS verwenden.
- **Container-Kontext**: Jedes Skript beginnt mit Container-Prüfung oder explizitem `ALTER SESSION SET CONTAINER = PDBORCL;`

---

## 🤝 Beitrag & Erweiterung

Geplante Komponenten für zukünftige Versionen:
- `SCHEMA_SEQUENCE_TEMPLATE.sql` – Template für konsistente Autoincrement-Sequences
- `SCHEMA_NAMING_CONVENTIONS.md` – Entwickler-Checkliste (Trigger-Präfixe, Index-Namierung)
- `SCHEMA_DDL_EXTRACT.sql` – Automatischer Export für Versionskontrolle
- `SCHEMA_VALIDATION_CHECKLIST.sql` – Post-DDL-Verifikation
- `SCHEMA_CLEANUP.sql` – Sauberes Decommissioning

---

## 📜 Lizenz

MIT License – siehe [LICENSE](LICENSE) für Details.

---

## 📞 Support & Fehlerberichte

Probleme oder Verbesserungsvorschläge? Issues willkommen!

---

## 🎯 Status

| Komponente | Status | Version |
|---|---|---|
| DB_CONNECT | ✅ Production | 1.0 |
| USER_ADMIN | ✅ Production | 1.0 |
| USER_ADMIN_PROFILE_SCHEDULER | ✅ Production | 1.0 |
| DBA_HEALTH_CHECK | ✅ Production | 1.0 |
| UNIFIED_AUDIT_POLICY | ✅ Production | 1.0 |
| NETWORK_LISTENER_HARDENING | ✅ Production | 1.0 |
| SCHEMA_BOOTSTRAP | ✅ Production | 1.0 |
| FLASHBACK_DATABASE_SETUP | ⚠️ Optional | 1.0 |
| EM_EXPRESS_SETUP | ⚠️ Deprecated | 1.0 |

---

**Erstellt für Oracle Database 21c, PDB PDBORCL**  
*Letzte Aktualisierung: 2026-07-20*
