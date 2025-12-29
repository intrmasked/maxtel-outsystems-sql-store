# OutSystems Server Action: GetOperatingPeriodsStructure

This blueprint outlines the logic for a Server Action that generates the list of rows/columns for the Operating Periods report, matching the `query.sql` implementation.

## Input Parameters
- `SelectedView` (Text): 'D', 'G', or 'A'
- `ActiveTenderTypes` (List of Structure): The list of tenders active for the selected sites/range.

## Output Parameters
- `ReportStructure` (List of Structure): Matching the `outputStructure` in `metadata.json`.

## Logical Steps

### 1. Initialize List
Create a local variable `RowStructureList` of type `ReportStructure List`.

### 2. Add 'Expected Total Takings' (Conditional)
- **If**: `SelectedView = "D"`
- **Action**: ListAppend to `RowStructureList`:
    - Name: "Expected Total Takings"
    - SortOrder: 10
    - TenderTypeId: NullIdentifier()

### 3. Add 'Dynamic Tenders'
- **Action**: ForEach `Record` in `ActiveTenderTypes`:
    - ListAppend to `RowStructureList`:
        - Name: `Record.Name`
        - SortOrder: 50
        - TenderTypeId: `Record.TenderTypeId`

### 4. Add 'Actual Total Takings' (Always)
- **Action**: ListAppend to `RowStructureList`:
    - Name: "Actual Total Takings"
    - SortOrder: 90
    - TenderTypeId: NullIdentifier()

### 5. Add 'Variance' (Conditional)
- **If**: `SelectedView = "D"`
- **Action**: ListAppend to `RowStructureList`:
    - Name: "Variance"
    - SortOrder: 100
    - TenderTypeId: NullIdentifier()

### 6. Add 'Information' (Always)
- **Action**: ListAppend to `RowStructureList`:
    - Name: "Information"
    - SortOrder: 110
    - TenderTypeId: NullIdentifier()

---

### Sorting Verification
The SQL query uses these exact `SortOrder` values to ensure the UI data aligns perfectly with this structure generator.
