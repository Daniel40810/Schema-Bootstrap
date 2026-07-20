# Schema Bootstrap – Administrative Rahmenbedingungen (Oracle 21c)

Runbook/Skript, das die administrativen Grundlagen für ein neu angelegtes Schema herstellt – **nach** `USER_ADMIN.CREATE_USER` und **vor** der ersten fachlichen DDL (Tabellen, Constraints, ...).

Fügt sich in den bestehenden Ablauf des Oracle DBA Toolkits ein:

```
USER_ADMIN.CREATE_USER(...)   ->  Schema/User existiert
SCHEMA_BOOTSTRAP.sql          ->  administrative Rahmenbedingungen (dieses Runbook)
Fachliche DDL                 ->  eigentliche Tabellen/Objekte
```

---

## Inhaltsverzeichnis

- [Voraussetzungen](#voraussetzungen)
- [Was das Skript macht](#was-das-skript-macht)
- [Parameter](#parameter)
- [Ausführung](#ausführung)
- [Nach der DDL-Migration](#nach-der-ddl-migration)
- [Sicherheitshinweise](#sicherheitshinweise)
- [Erweiterungsmöglichkeiten](#erweiterungsmöglichkeiten)

---

## Voraussetzungen

| Anforderung | Details |
|---|---|
| Datenbank | Oracle Database 21c |
| Vorbedingung | Schema wurde bereits über `USER_ADMIN.CREATE_USER` angelegt |
| Rechte | Ausführung als `SYS AS SYSDBA` |
| Container | `PDBORCL` (Skript prüft das selbst und bricht bei falschem Container ab) |
| Client | Oracle SQL Developer 24.3.1 (empfohlen) oder SQL\*Plus |

> **Hinweis:** In SQL Developer mit **F5** (Run Script) ausführen, nicht mit Strg+Enter – das Skript enthält mehrere `/`-terminierte PL/SQL-Blöcke.

---

## Was das Skript macht

| # | Schritt | Zweck |
|---|---|---|
| 0 | Container-Guard | Bricht ab, falls nicht in `PDBORCL` – verhindert versehentliche Arbeit in `CDB$ROOT` |
| 1 | Tablespace & Quota | Setzt Default-/Temp-Tablespace explizit, begrenzt Quota statt `UNLIMITED` |
| 2 | Rollen statt Einzel-Grants | Weist `DB_CONNECT` zu; Vorlage für zusätzliche fachliche Rolle |
| 3 | Passwort-Profil | Stellt sicher, dass `USER_ADMIN_PROFILE` aktiv ist (idempotent) |
| 4 | NLS-Konsistenz | `AFTER LOGON`-Trigger setzt `NLS_LENGTH_SEMANTICS = CHAR` pro Session |
| 5 | Unified Auditing | Nimmt das Schema in `ADMIN_DDL_POLICY` auf |
| 6 | Guaranteed Restore Point | Sicherheitsnetz vor dem anstehenden DDL-Batch |
| 7 | Kontrolle | Zeigt Tablespace/Profil/Status sowie den gesetzten Restore Point zur Verifikation |

---

## Parameter

| Variable | Beschreibung | Beispiel |
|---|---|---|
| `schema_name` | Name des zuvor angelegten Schemas | `USER1` |
| `default_tbs` | Ziel-Tablespace für Nutzdaten | `USERS` |
| `temp_tbs` | Temporärer Tablespace | `TEMP` |
| `quota_mb` | Quota in MB auf `default_tbs` | `500` |
| `restore_point` | Name des Guaranteed Restore Points | `RP_BOOTSTRAP_USER1` (automatisch aus `schema_name` abgeleitet) |

Parameter stehen am Skriptanfang als `DEFINE`-Variablen und werden vor dem Lauf angepasst.

---

## Ausführung

```sql
ALTER SESSION SET CONTAINER = PDBORCL;
@SCHEMA_BOOTSTRAP.sql
```

Das Skript ist wiederholbar aufgebaut: ein erneuter Lauf mit denselben oder angepassten Parametern schlägt nicht fehl (z. B. wenn Quota oder Tablespace nachträglich korrigiert werden müssen).

---

## Nach der DDL-Migration

Der in Schritt 6 gesetzte Guaranteed Restore Point **muss** nach erfolgreicher fachlicher DDL wieder entfernt werden, sonst füllt sich die Fast Recovery Area:

```sql
DROP RESTORE POINT RP_BOOTSTRAP_<schema_name>;
```

---

## Sicherheitshinweise

- **Quota**: Kein `UNLIMITED` ohne konkreten Grund – begrenzt den Schaden bei fehlerhaften Bulk-Operationen.
- **Restore Point**: Guaranteed Restore Points sind kein Backup-Ersatz und können bei Nichtlöschung die Fast Recovery Area zum Hängen bringen (siehe Haupt-Toolkit-Dokumentation).
- **Auditing**: Schritt 5 setzt voraus, dass `ADMIN_DDL_POLICY` bereits im Rahmen von `UNIFIED_AUDIT_POLICY.sql` existiert.
- **NLS-Trigger**: Der `AFTER LOGON`-Trigger gilt nur für Sessions dieses einen Schemas, nicht global.

---

## Erweiterungsmöglichkeiten

- Zusätzliche fachliche Rolle statt Einzel-Grants (Vorlage im Skript enthalten, auskommentiert)
- Sequence-Namenskonvention (`<TABELLE>_SEQ`) für die nachfolgende DDL dokumentieren, passend zur bestehenden Sequence+Trigger-Konvention des Toolkits
- Bei Bedarf: schemaspezifische Unified-Audit-Policy statt Zuordnung zur globalen `ADMIN_DDL_POLICY`
