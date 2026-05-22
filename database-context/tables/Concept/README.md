# Table: Concept

**OutSystems Entity**: Concept
**Module**: Access_CS (assumed — same as MaxtelApp)
**Purpose**: Defines business concepts/brands within the Maxtel system. A concept groups sites under a common brand identity.
**Last Updated**: 2026-05-19

---

## Overview

The Concept table stores brand/concept definitions. Each concept represents a distinct business brand (e.g. McDonald's, McCafé). Sites belong to a concept, and various features (reports, settings) can be scoped per-concept.

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Id` | BIGINT | PK, NOT NULL | Auto-generated primary key |
| `Name` | VARCHAR | NOT NULL | Concept/brand name (e.g. "McDonald's") |
| `Is_Active` | BIT | DEFAULT 1 | Whether this concept is currently active |

---

## Key Constraints

### Primary Key
- `Id` - Auto-generated identifier

---

## Data Characteristics

### Row Count
- Small lookup table — likely < 10 rows

### Common Values
- ConceptId 129 is the standard/default concept used in testing

---

## Relationships

### Tables That Reference This Table
- **ReportModules** - Scopes report-module assignments per concept
  - Join: `ReportModules.ConceptId = Concept.Id`
- **Site** - Sites belong to a concept (assumed)

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-05-19 | Claude | Initial documentation from screenshot |
