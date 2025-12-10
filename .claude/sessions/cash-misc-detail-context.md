# Session: Cash Misc - Detail Screen - 2025-12-08

## Original Story/Requirements

**User Request (exact):**
```
Cash Misc - Detail Screen

Datagrid list for SWCCashDrawers for this SWCPeriod using following fields:
POS = SWCCashDrawer.PosId
Type = SalesFact.Pod (use GetPODFullName action).
Difference = SWCPeriod.GTFinal - GTInitial
Variance = SWCPeriod.TotalVariance
Promo, Discounts, EmployeeMeals (Crew), ManagerMeals, Reduction = All these fields now in the SWCCashDrawer table. Use Amount for Dollars and Count for Guest Count.

Offline Eftpos = SWCCashDrawerTender.NetAmount / .TransactionCount filtered for this Tender type,
Petty Cash = SWCCashDrawerTender.NetAmount /.TransactionCount filtered for this Tender type,
Cash Refund = SWCCashDrawerTender.RefundAmount / .RefundCount filtered for this Tender type,
Eftpos Refund = SWCCashDrawerTender.RefundAmount / .RefundCount filtered for EFTPOS, MOP, Doordash, UberEats, Delivereasy,
Cashier = SWC.OperatorUserId (join to get name)
Manager = leave blank

When filter is Guests the Transaction type fields above are used instead. The Difference and Variance columns are hidden.
When filter is Average [message cut off]
```

**Additional Context:**
- Filter by SiteId and Date (via SWCPeriod)
- View filter: Dollars, Guests, Average
- When Guests: Use Count fields, hide Difference and Variance
- When Dollars: Use Amount fields
- When Average: Calculate Amount/Count
- Output: One row per POS/Cashier

---

## Status

- [ ] Complete
- [X] In Development
- [ ] Needs Review

**Current step**: Query complete with comprehensive test coverage - ready for user testing

---

## Tables Needed

### Already Documented:
1. ✅ **SWCCashDrawer** - Main source (PosId, GT values, Promo, Discounts, Meals, Reduction)
2. ✅ **SWCPeriod** - Filter and TotalVariance
3. ✅ **SWCPosTerminal** - Pod for Type column
4. ✅ **SWCCashDrawerTender** - Tender-specific amounts (Offline Eftpos, Petty Cash, Refunds)
5. ✅ **TenderType** - Filter tender types

### Need Documentation:
1. ❓ **User/Employee Table** - For Cashier name (OperatorUserId)
   - Need to ask user: What table stores user/employee names?
   - Join pattern: SWCCashDrawer.OperatorUserId = ???

---

## Columns Required

| Column | Source | Calculation | View Filter |
|--------|--------|-------------|-------------|
| POS | SWCCashDrawer.PosId | Direct | All |
| Type | SWCPosTerminal.Pod | GetPODFullName(Pod) | All |
| Difference | SWCCashDrawer | FinalGT - InitialGT | Dollars/Average only |
| Variance | SWCPeriod.TotalVariance | Direct | Dollars/Average only |
| Promo | SWCCashDrawer | Amount (D), Count (G), Amount/Count (A) | All |
| Discounts | SWCCashDrawer | Amount (D), Count (G), Amount/Count (A) | All |
| EmployeeMeals | SWCCashDrawer | CrewMealsAmount/Count | All |
| ManagerMeals | SWCCashDrawer | ManagerMealsAmount/Count | All |
| Reduction | SWCCashDrawer | ReductionAmount/Count | All |
| Offline Eftpos | SWCCashDrawerTender | NetAmount/TransactionCount (filtered) | All |
| Petty Cash | SWCCashDrawerTender | NetAmount/TransactionCount (filtered) | All |
| Cash Refund | SWCCashDrawerTender | RefundAmount/RefundCount (Cash) | All |
| Eftpos Refund | SWCCashDrawerTender | RefundAmount/RefundCount (Eftpos group) | All |
| Cashier | OperatorUserId → User table | Join to get name | All |
| Manager | - | NULL (leave blank) | All |

---

## Questions for User

1. **User/Employee Table:**
   - What table stores user/employee names for Cashier column?
   - What's the join key? (SWCCashDrawer.OperatorUserId = ???)
   - What column contains the name? (FirstName + LastName, DisplayName, etc.)

2. **TenderType Names:**
   - What are the exact TenderType names/IDs for:
     - Offline Eftpos
     - Petty Cash
   - Confirm Eftpos Refund group: EFTPOS, MOP, Doordash, UberEats, Delivereasy (same as TenderTypeId IN (10, 13, 16, 19, 21)?)

3. **Reduction Field:**
   - Use ReductionBeforeTotal or ReductionAfterTotal?
   - Or sum both?

4. **View Parameter:**
   - How should view filter be passed? @SelectedView with 'D', 'G', 'A'?

---

## Next Steps

1. Get answers to questions above
2. Document User/Employee table (if needed)
3. Build query with conditional logic for view filter
4. Implement CASE statements for Dollars/Guests/Average
5. Add tender type filtering

---

## Quick Resume

**To continue this work:**
1. Answer questions about User table and TenderType specifics
2. Create query structure similar to Product Sales By Drawer
3. Use InputVar CTE pattern for view filter (@SelectedView)
4. Conditional columns based on view filter

**Status:** Query implemented with full test coverage

**Recent Updates (2025-12-10):**
- ✅ Main query completed with performance optimization (pre-aggregation pattern)
- ✅ All 10 test files created for comprehensive column verification
- ✅ Fixed OutSystems sandbox issue (removed multiple SELECT statements)
- ✅ Updated claude.md with OutSystems test query rules
- ✅ Created OUTPUT-STRUCTURE.md for frontend development
- ✅ Removed SortOrder column (simplified to CASE in ORDER BY)
- ✅ Git commit: 222d46a "Cash Misc Detail: Complete query implementation with comprehensive test coverage"
- ✅ Pushed to remote repository

**Test Coverage:**
1. test-1-difference-variance.sql - Difference & Variance calculations
2. test-2-promo.sql - Promo Amount/Count
3. test-3-discounts.sql - Discount Amount/Count
4. test-4-employee-meals.sql - Crew Meals Amount/Count
5. test-5-manager-meals.sql - Manager Meals Amount/Count
6. test-6-reduction.sql - Reduction Before/After/Count
7. test-7-offline-eftpos.sql - Offline Eftpos (TenderTypeId=9)
8. test-8-petty-cash.sql - Petty Cash (TenderTypeId=22)
9. test-9-cash-refund.sql - Cash Refunds (IsCash=1)
10. test-10-eftpos-refund.sql - Eftpos Refunds (TenderTypeId IN 10,13,16,19,21)

**Key Learnings:**
- OutSystems sandbox stops after first result set
- Use window functions (OVER clause) for verification stats in single SELECT
- Never use multiple SELECT statements in test queries
