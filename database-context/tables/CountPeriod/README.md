# CountPeriod

## Purpose
Reference table for stock count frequencies. Used by `CentralStockItem.DefaultCountPeriodId` to indicate how often an item should be counted.

## Columns
| Column | Type | Notes |
|--------|------|-------|
| Id | Integer | PK |
| Label | Text | Display name (Daily, Weekly, Monthly, Never) |
| Order | Integer | Sort order |

## Known Values
| Id | Label | Order |
|----|-------|-------|
| 1 | Daily | 1 |
| 2 | Never | 4 |
| 3 | Weekly | 2 |
| 4 | Monthly | 3 |

## Relationships
- `CentralStockItem.DefaultCountPeriodId` → `CountPeriod.Id`
