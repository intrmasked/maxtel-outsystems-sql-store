# Cash Misc - Detail Screen Output Structure

## Input Parameters

| Parameter | Type | Values | Description |
|-----------|------|--------|-------------|
| `@SiteId` | Long Integer | e.g., 3187 | Site/Store ID |
| `@Date` | Date | 'YYYY-MM-DD' | Business date |
| `@SelectedView` | Text (1 char) | 'D', 'G', 'A' | View filter: Dollars, Guests, Average |

---

## Output Columns

### Fixed Columns (Always visible)

| Column | Data Type | Description | Example Value |
|--------|-----------|-------------|---------------|
| `POS` | Long Integer | POS Terminal ID | 1, 2, 3, NULL (for Total row) |
| `Pod` | Text | POS Type Name (converted from code) | "Counter", "Drive-Thru", "Kiosk", "Delivery", "Total" |

**Pod Name Conversion:**
- 'FC' → 'Counter'
- 'DT' → 'Drive-Thru'
- 'CSO' → 'Kiosk'
- 'DELIVERY' → 'Delivery'
- Other codes → Return as-is

---

### Conditional Columns (Visibility based on @SelectedView)

#### Difference & Variance (Hidden when @SelectedView = 'G')

| Column | Data Type | Visible When | Description |
|--------|-----------|--------------|-------------|
| `Difference` | Decimal | 'D', 'A' | FinalGT - InitialGT |
| `Variance` | Decimal | 'D', 'A' | ⚠️ Currently: Period total variance (needs clarification per POS) |

---

### Dynamic Columns (Value changes based on @SelectedView)

All columns below change behavior based on the view filter:

| Column | When 'D' (Dollars) | When 'G' (Guests) | When 'A' (Average) |
|--------|-------------------|-------------------|-------------------|
| `Promo` | PromoAmount | PromoCount | PromoAmount / PromoCount |
| `Discounts` | DiscountAmount | DiscountCount | DiscountAmount / DiscountCount |
| `EmployeeMeals` | CrewMealsAmount | CrewMealsCount | CrewMealsAmount / CrewMealsCount |
| `ManagerMeals` | ManagerMealsAmount | ManagerMealsCount | ManagerMealsAmount / ManagerMealsCount |
| `ReductionBeforeTotal` | ReductionBeforeTotal | ReductionCount | ReductionBeforeTotal / ReductionCount |
| `ReductionAfterTotal` | ReductionAfterTotal | ReductionCount | ReductionAfterTotal / ReductionCount |
| `OfflineEftpos` | OfflineEftposAmount | OfflineEftposCount | OfflineEftposAmount / OfflineEftposCount |
| `PettyCash` | PettyCashAmount | PettyCashCount | PettyCashAmount / PettyCashCount |
| `CashRefund` | CashRefundAmount | CashRefundCount | CashRefundAmount / CashRefundCount |
| `EftposRefund` | EftposRefundAmount | EftposRefundCount | EftposRefundAmount / EftposRefundCount |

**Data Type**: All dynamic columns return `Decimal(18,2)`

---

### Fixed Columns (Always visible)

| Column | Data Type | Description | Example Value |
|--------|-----------|-------------|---------------|
| `Cashier` | Text | Cashier name from User table | "John Smith", NULL (for Total row) |
| `Manager` | Text | Manager name (currently NULL) | NULL |

---

## Row Structure

### Data Rows
- One row per POS/Cashier combination
- Contains actual drawer data for that cashier's session
- Sorted by: `POS ASC, Cashier ASC`

### Total Row
- Single row with aggregated totals (always last)
- `POS` = NULL
- `Pod` = "Total"
- `Cashier` = NULL
- `Manager` = NULL
- All numeric columns = SUM of all data rows

---

## Example Output

### When @SelectedView = 'D' (Dollars)

| POS | Pod | Difference | Variance | Promo | Discounts | EmployeeMeals | ManagerMeals | ReductionBeforeTotal | ReductionAfterTotal | OfflineEftpos | PettyCash | CashRefund | EftposRefund | Cashier | Manager |
|-----|-----|------------|----------|-------|-----------|---------------|--------------|---------------------|---------------------|---------------|-----------|------------|--------------|---------|---------|
| 1 | Counter | 1250.50 | 2.60 | 45.00 | 120.50 | 25.00 | 15.00 | 10.00 | 5.00 | 0.00 | 20.00 | 10.00 | 5.00 | John Smith | NULL |
| 2 | Drive-Thru | 980.25 | 2.60 | 30.00 | 85.75 | 20.00 | 10.00 | 8.00 | 3.00 | 15.00 | 0.00 | 5.00 | 2.00 | Jane Doe | NULL |
| NULL | Total | 2230.75 | 5.20 | 75.00 | 206.25 | 45.00 | 25.00 | 18.00 | 8.00 | 15.00 | 20.00 | 15.00 | 7.00 | NULL | NULL |

---

### When @SelectedView = 'G' (Guests)

| POS | Pod | Difference | Variance | Promo | Discounts | EmployeeMeals | ManagerMeals | ReductionBeforeTotal | ReductionAfterTotal | OfflineEftpos | PettyCash | CashRefund | EftposRefund | Cashier | Manager |
|-----|-----|------------|----------|-------|-----------|---------------|--------------|---------------------|---------------------|---------------|-----------|------------|--------------|---------|---------|
| 1 | Counter | NULL | NULL | 5.00 | 12.00 | 3.00 | 2.00 | 2.00 | 1.00 | 0.00 | 4.00 | 2.00 | 1.00 | John Smith | NULL |
| 2 | Drive-Thru | NULL | NULL | 3.00 | 8.00 | 2.00 | 1.00 | 1.00 | 1.00 | 3.00 | 0.00 | 1.00 | 1.00 | Jane Doe | NULL |
| NULL | Total | NULL | NULL | 8.00 | 20.00 | 5.00 | 3.00 | 3.00 | 2.00 | 3.00 | 4.00 | 3.00 | 2.00 | NULL | NULL |

**Note**: Difference and Variance are hidden when view = 'G'

---

### When @SelectedView = 'A' (Average)

| POS | Pod | Difference | Variance | Promo | Discounts | EmployeeMeals | ManagerMeals | ReductionBeforeTotal | ReductionAfterTotal | OfflineEftpos | PettyCash | CashRefund | EftposRefund | Cashier | Manager |
|-----|-----|------------|----------|-------|-----------|---------------|--------------|---------------------|---------------------|---------------|-----------|------------|--------------|---------|---------|
| 1 | Counter | 1250.50 | 2.60 | 9.00 | 10.04 | 8.33 | 7.50 | 5.00 | 5.00 | 0.00 | 5.00 | 5.00 | 5.00 | John Smith | NULL |
| 2 | Drive-Thru | 980.25 | 2.60 | 10.00 | 10.72 | 10.00 | 10.00 | 8.00 | 3.00 | 5.00 | 0.00 | 5.00 | 2.00 | Jane Doe | NULL |
| NULL | Total | 2230.75 | 5.20 | 9.38 | 10.31 | 9.00 | 8.33 | 6.00 | 4.00 | 5.00 | 5.00 | 5.00 | 3.50 | NULL | NULL |

**Note**: Average = Amount / Count for each column

---

## Frontend Display Rules

### Column Headers
- When `@SelectedView = 'D'`: All columns show dollar values
- When `@SelectedView = 'G'`: All columns show counts (guest count/transaction count)
- When `@SelectedView = 'A'`: All columns show averages (amount per transaction)

### Visibility Rules
1. **Always show**: POS, Pod, Cashier, Manager, all dynamic columns
2. **Conditional (hide when 'G')**: Difference, Variance

### Formatting Recommendations
- **Dollars ('D')**: 2 decimal places with currency symbol ($1,250.50)
- **Guests ('G')**: Whole numbers or 2 decimal places (5.00)
- **Average ('A')**: 2 decimal places ($9.38)
- **Total Row**: Bold text, different background color

### Sort Order
1. Data rows first, Total row last
2. Within data rows: `POS ASC` (POS terminal number)
3. Within POS: `Cashier ASC` (alphabetically by cashier name)

---

## Known Issues / Pending Clarifications

⚠️ **Variance Field**: Currently returns `p.TotalVariance` (period total variance = 2.6) for all rows.
- **Issue**: Same value repeated for all POS/drawers
- **Expected**: Should show variance per POS/drawer
- **Awaiting**: User clarification on correct field or calculation

---

## OutSystems Integration Notes

### Input Parameters Setup
```
SiteId (Long Integer) - Expand Inline: No
Date (Date) - Expand Inline: No
SelectedView (Text) - Expand Inline: No
```

### Output Structure (OutSystems)
Create a Structure with the following attributes:
- POS: Long Integer
- Pod: Text
- Difference: Decimal (Optional)
- Variance: Decimal (Optional)
- Promo: Decimal
- Discounts: Decimal
- EmployeeMeals: Decimal
- ManagerMeals: Decimal
- ReductionBeforeTotal: Decimal
- ReductionAfterTotal: Decimal
- OfflineEftpos: Decimal
- PettyCash: Decimal
- CashRefund: Decimal
- EftposRefund: Decimal
- Cashier: Text
- Manager: Text

---

## Testing Notes

Test with different view filters:
1. 'D' - All amount columns should show dollar values
2. 'G' - All amount columns should show counts, Difference/Variance hidden
3. 'A' - All amount columns should show averages (amount/count)

Verify Total row (SortOrder = 1) appears last and sums all data rows correctly.
