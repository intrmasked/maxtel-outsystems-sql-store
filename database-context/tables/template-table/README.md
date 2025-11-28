# Table: [Table Name]

**OutSystems Entity**: [Entity Name]  
**Database Table**: [dbo].[TableName]  
**Purpose**: [What this table stores and why it exists]  
**Last Updated**: YYYY-MM-DD

---

## Overview

*Detailed description of what this table does and its business purpose within the MaxTel system.*

**Example**: If this were a Customer table:
> "The Customer table stores all active and inactive customer records for MaxTel. It maintains core customer information including contact details, registration dates, and status. Every order, transaction, and communication is linked back to this table."

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `column_id` | INT | PK, NOT NULL | Primary key, auto-increment |
| `column_name` | VARCHAR(100) | NOT NULL, UNIQUE | Customer name - must be unique |
| `column_date` | DATETIME | NOT NULL | Timestamp when record created |
| `column_status` | VARCHAR(20) | DEFAULT 'Active' | Status: Active, Inactive, Pending |
| `column_reference` | INT | FK | Foreign key to [RelatedTable] |
| `column_flag` | BIT | DEFAULT 0 | Boolean flag for something |

---

## Key Constraints

### Primary Key
- `column_id` - Unique identifier for each record

### Unique Constraints
- `column_name` - No duplicate values allowed

### Foreign Keys
- `column_reference` → [RelatedTable].`[RelatedColumn]`
  - Relationship: [One-to-Many / Many-to-One]
  - Cascade on delete: [Yes/No]

### Indexes
- IX_ColumnName - Index on `column_name` for faster searching
- IX_ColumnStatus - Index on `column_status` for filtering

---

## Relationships

### Tables That Reference This Table
- **[ChildTable]** - Has many records per this table's record
  - Join: `ChildTable.parent_id = ThisTable.id`
  - Use case: Getting all child records for a parent

### Tables This Table References
- **[ParentTable]** - This table points to parent records
  - Join: `ThisTable.parent_id = ParentTable.id`
  - Use case: Getting parent info for filtering

---

## Data Characteristics

### Row Count
- Typical: ~[X] million rows
- Growth rate: [X% per month]

### Data Distribution
- Distribution is [even/skewed] across `column_name`
- Most queries filter on `column_status` (should use index)

### Common Values
- `column_status` values: Active (70%), Inactive (25%), Pending (5%)
- `column_type` values: Type_A (40%), Type_B (35%), Type_C (25%)

---

## Common Query Patterns

### Pattern 1: Get Recent Records
```sql
SELECT TOP 100
    column_id,
    column_name,
    column_date
FROM [dbo].[TableName]
WHERE column_status = 'Active'
ORDER BY column_date DESC
```

### Pattern 2: Join with Related Table
```sql
SELECT 
    t.column_id,
    t.column_name,
    rt.related_column
FROM [dbo].[TableName] t
INNER JOIN [dbo].[RelatedTable] rt 
    ON t.column_reference = rt.id
WHERE t.column_status = 'Active'
```

### Pattern 3: Aggregate by Status
```sql
SELECT 
    column_status,
    COUNT(*) as record_count,
    MAX(column_date) as last_date
FROM [dbo].[TableName]
GROUP BY column_status
```

---

## Important Notes for OutSystems Advanced SQL Block

⚠️ **Considerations for OutSystems Advanced SQL**:
- Table schema may be modified by OutSystems - check [System tables prefix](https://success.outsystems.com/documentation)
- Column names may have OutSystems prefix in actual DB (e.g., `osp_` or `cust_`)
- Always use proper table aliases in Advanced SQL queries
- Date functions: Use CONVERT() or FORMAT() for OutSystems compatibility

✅ **Best Practices**:
- Use parameterized queries for filtering
- Include proper indexing considerations in comments
- Document any OutSystems specific behavior
- Test with OutSystems test data before production use

---

## Visual References (Optional)

**Note**: Only add an `images/` folder if visual aids significantly help understanding.

Most table docs don't need images. Use them only for:
- Complex ER diagrams with many relationships
- Unusual data structures that text can't describe well

For most tables, clear text documentation is sufficient.

---

## Related Tables

- [Table 1](../table-1/README.md) - Description of relationship
- [Table 2](../table-2/README.md) - Description of relationship
- [Table 3](../table-3/README.md) - Description of relationship

---

## FAQ / Common Questions

**Q: Can I update this table directly?**  
A: [Answer based on OutSystems permissions]

**Q: What's the retention policy?**  
A: [Describe how long data is kept]

**Q: How often is this data updated?**  
A: [Real-time, batch, scheduled, etc.]

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| YYYY-MM-DD | Team | Initial documentation |
| YYYY-MM-DD | Team | Added relationships |
