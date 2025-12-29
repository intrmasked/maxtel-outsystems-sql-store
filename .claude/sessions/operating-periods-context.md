# Session Context: Operating Periods Refactor (Screen 2)

Refactoring the "Operating Periods" report screen into the repository-standard Advanced SQL structure.

## Status
- [x] Complete / [ ] In Progress / [ ] Needs Review
- Current step: Refactor finalized and committed to git.
- Incomplete items: None.

## Tables Documentation Created
- N/A

## Queries Created
- `queries/reports/operating-periods/query.sql` (v1.1.0)
- `queries/reports/operating-periods/tests/test-ssms.sql`
- `queries/utilities/get-tender-list/query.sql` (Global Utility)
- `queries/utilities/get-tender-list/README.md` (Logic Blueprint)

## Key Decisions
- **Grand Total Standardization**: SiteId = 0 and SiteName = 'Grand Total' for all total rows.
- **Hierarchical Subtotals**: Implemented Overall Grand Total (BusDate=NULL) followed by Daily Grand Totals (BusDate=Actual Date) to allow easier filtering by date.
- **Dynamic View Allocation**: Handled Dollars ('D'), Guests ('G'), and Average ('A') via `@SelectedView` parameter.
- **Conditional Visibility**: Expected and Variance rows are now omitted when the view is not Dollars ('D').
- **Information Row Cleanup**: Removed redundant "Information" rows from Daily Grand Totals to reduce clutter.
- **New Project Standard**: All queries now require MCP Sandbox verification and an OutSystems-importable JSON Structure definition.

## Next Steps
1. Verify if further refinements are needed.
2. Ensure metadata.json is fully aligned with the query output.

## Quick Resume
To continue:
1. Review `queries/reports/operating-periods/query.sql`.
2. Run tests via the MCP bridge if needed.
