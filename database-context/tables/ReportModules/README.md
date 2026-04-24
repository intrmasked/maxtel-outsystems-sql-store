# Table: ReportModules

**OutSystems Entity**: ReportModules
**Module**: Report_CS
**Purpose**: Many-to-many join table linking SupportedReport to MaxtelApp, allowing a report to be assigned to multiple operational modules.
**Last Updated**: 2026-04-24

---

## Overview

ReportModules replaces the old `Module` text field on SupportedReport. Instead of a single module string, reports can now be assigned to one or more MaxtelApp modules via this join table. This supports the Reports reorganisation (Story #3786) where reports are grouped by module in the UI.

**Status**: NEW TABLE — needs to be created in OutSystems and seeded from existing SupportedReport.Module values.

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Id` | BIGINT | PK, NOT NULL | Auto-generated primary key |
| `SupportedReportId` | BIGINT | FK, NOT NULL | References SupportedReport.Id |
| `MaxtelAppId` | BIGINT | FK, NOT NULL | References MaxtelApp.Id (stored by value, no cross-service FK) |

---

## Key Constraints

### Primary Key
- `Id` - Auto-generated identifier

### Unique Constraints
- Composite unique on (`SupportedReportId`, `MaxtelAppId`) — a report can only be assigned to a module once

### Foreign Keys
- `SupportedReportId` → SupportedReport.Id (same module — real FK)
- `MaxtelAppId` → MaxtelApp.Id (cross-service — stored by value, no DB-level FK)

---

## Relationships

### Tables This Table References
- **SupportedReport** - The report being assigned
  - Join: `ReportModules.SupportedReportId = SupportedReport.Id`
- **MaxtelApp** - The module the report is assigned to
  - Join: `ReportModules.MaxtelAppId = MaxtelApp.Id`

---

## Seeding Strategy

Seed from existing `SupportedReport.Module` values:
1. Map each distinct `Module` string to its corresponding `MaxtelApp.Id`
2. INSERT one ReportModules row per (SupportedReportId, MaxtelAppId) pair

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-04-24 | Claude | Initial documentation — table not yet created |
