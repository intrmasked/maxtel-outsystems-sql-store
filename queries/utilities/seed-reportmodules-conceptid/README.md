# Seed ReportModules ConceptId

## Purpose
One-off data migration to assign ConceptId = 129 (default concept) to all existing ReportModules rows after adding the ConceptId column to the table.

## Context
- **Story**: [#3824](https://dev.azure.com/MaxtelNZ/Scheduling/_workitems/edit/3824)
- **Why**: ReportModules now needs a ConceptId to scope report-module assignments per concept/brand. All existing rows predate this column and need a default value.

## Usage
1. Add ConceptId column (BIGINT) to ReportModules entity in OutSystems
2. Run `query.sql` once to seed all existing rows with ConceptId = 129
3. Verify with `tests/test-ssms.sql`

## Tables
- `ReportModules` — UPDATE ConceptId

## Important
- Run ONCE after adding the column
- Safe to re-run (WHERE clause skips already-set rows)
- Does not affect rows added after the column is set up with a default in OutSystems
