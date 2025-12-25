# Operating Periods Tenders (Screen 2)

## Purpose
This query provides the data for the "Operating Periods" screen (often called the Check/Tender screen). It calculates dynamic tender columns plus fixed metrics like Expected Total Takings, Actual Total Takings, and Variance.

## Features
- **Dynamic Tenders**: Automatically identifies and aggregates all tender types active across the selected sites and date range.
- **Grand Totals**: Provides a "Total" row (where `OperatingPeriodId` is NULL) at the top of the set.
- **Multi-View Support**: Automatically handles Dollars, Guests, and Weighted Average views.
- **Information Column**: Includes a placeholder column for UI interaction buttons.

## Parameters
- `@SiteIds`: Comma-separated list of Long Integers (Expand Inline = YES).
- `@StartDate`: Beginning of date range.
- `@EndDate`: End of date range.
- `@SelectedView`: View type ('D', 'G', 'A').

## Usage in OutSystems
1. The Data Action should first fetch the list of `SWCPeriod` entities to get the "Parent" rows (SiteName, Date).
2. Execute this Advanced SQL to get the "Child" data (`ValueByTender` list).
3. Inside the loop of SWCPeriods:
   - Use `ListFilter` to select items where `OperatingPeriodId` matches the current period.
   - For the Grand Total row (inserted at index 0), use items where `OperatingPeriodId` is NULL.

## Versioning
- **v1.0.0**: Initial implementation using standard `UNION ALL` pattern for rows and totals.
