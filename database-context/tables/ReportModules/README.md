# Table: ReportModules

**OutSystems Entity**: ReportModules
**Module**: Report_CS
**Purpose**: Many-to-many join table linking SupportedReport to MaxtelApp per Concept, allowing a report to be assigned to multiple operational modules scoped by concept.
**Last Updated**: 2026-05-26

---

## Overview

ReportModules replaces the old `Module` text field on SupportedReport. Instead of a single module string, reports can now be assigned to one or more MaxtelApp modules via this join table. This supports the Reports reorganisation (Story #3786) where reports are grouped by module in the UI.

As of Story #3824, each assignment is scoped to a Concept (brand). This means the same report can be assigned to different modules for different concepts, or excluded from a concept entirely.

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Id` | BIGINT | PK, NOT NULL | Auto-generated primary key |
| `SupportedReportId` | BIGINT | FK, NOT NULL | References SupportedReport.Id |
| `MaxtelAppId` | BIGINT | FK, NOT NULL | References MaxtelApp.Id (stored by value, no cross-service FK) |
| `ConceptId` | BIGINT | FK, NOT NULL | References Concept.Id — scopes assignment to a concept/brand |

---

## Key Constraints

### Primary Key
- `Id` - Auto-generated identifier

### Unique Constraints
- Composite unique on (`SupportedReportId`, `MaxtelAppId`, `ConceptId`) — a report can only be assigned to a module once per concept

### Foreign Keys
- `SupportedReportId` → SupportedReport.Id (same module — real FK)
- `MaxtelAppId` → MaxtelApp.Id (cross-service — stored by value, no DB-level FK)
- `ConceptId` → Concept.Id (cross-service — stored by value, no DB-level FK)

---

## Relationships

### Tables This Table References
- **SupportedReport** - The report being assigned
  - Join: `ReportModules.SupportedReportId = SupportedReport.Id`
- **MaxtelApp** - The module the report is assigned to
  - Join: `ReportModules.MaxtelAppId = MaxtelApp.Id`
- **Concept** - The concept/brand this assignment is scoped to
  - Join: `ReportModules.ConceptId = Concept.Id`

---

## Seeding Strategy

1. Original seed: Map existing `SupportedReport.Module` values to `MaxtelApp.Id`, INSERT rows
2. ConceptId seed (Story #3824): UPDATE all existing rows to ConceptId = 129 (default concept)

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-04-24 | Claude | Initial documentation — table not yet created |
| 2026-05-19 | Claude | Added ConceptId column (Story #3824) |
| 2026-05-26 | Claude | UniqueReportModule constraint updated to include ConceptId (Story #3824) |
