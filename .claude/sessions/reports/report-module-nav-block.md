# Block: ReportModuleNav — Build Guide

**Story:** #3787 — Report Module UI
**Module:** Report_UI
**Purpose:** Sidebar navigation block showing module groups with report counts

---

## Block Structure

### Input Parameters

| Input | Type | Mandatory | Description |
|---|---|---|---|
| BusinessUserId | Long Integer | Yes | Logged-in user (passed to GetReportsForModule) |

### Events

| Event | Parameters | Description |
|---|---|---|
| OnModuleSelected | MaxtelAppId (Long Integer), ModuleName (Text) | Fires when user clicks a module |

### Local Variables

| Variable | Type | Description |
|---|---|---|
| ModuleList | ReportModuleItem List | Sidebar items from API |
| ActiveMaxtelAppId | Long Integer | Currently highlighted module |

---

## Data Flow

```
On Initialize / On Ready
├─ Data Action: FetchModules
│   └─ Call GetReportModuleList (Service Action)
│       └─ Returns: ModuleList (ReportModuleItem List)
│
├─ After Fetch (On After Fetch):
│   ├─ If ModuleList.Length > 0
│   │   ├─ ActiveMaxtelAppId = ModuleList[0].MaxtelAppId
│   │   └─ Trigger OnModuleSelected(ModuleList[0].MaxtelAppId, ModuleList[0].ModuleName)
│   └─ Else → empty state (no modules)
```

---

## Widget Tree

```
Container (class: "report-nav")
│
├─ List Widget (Source: ModuleList)
│   └─ List Item (class: "report-nav-item" + active class)
│       │
│       ├─ Container (class: "report-nav-link", OnClick: ModuleClicked)
│       │   ├─ Text: ModuleName
│       │   └─ Container (class: "report-nav-count")
│       │       └─ Text: "(" + ReportCount + ")"
│       │
│       └─ (no nested content)
```

---

## Client Actions

### ModuleClicked
```
Input: MaxtelAppId (Long Integer), ModuleName (Text)
│
├─ Assign: ActiveMaxtelAppId = MaxtelAppId
└─ Trigger Event: OnModuleSelected(MaxtelAppId, ModuleName)
```

---

## CSS Classes

### Container: `.report-nav`
```css
.report-nav {
    display: flex;
    flex-direction: column;
    gap: 0;
    padding: 8px 0;
}
```

### List Item: `.report-nav-item`
```css
.report-nav-item {
    list-style: none;
    padding: 0;
    margin: 0;
}
```

### Link: `.report-nav-link`
```css
.report-nav-link {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 10px 16px;
    cursor: pointer;
    color: #333;
    font-size: 14px;
    font-weight: 500;
    text-decoration: none;
    transition: background-color 0.15s ease, color 0.15s ease;
    border-left: 3px solid transparent;
}

.report-nav-link:hover {
    background-color: #f5f5f5;
}
```

### Active State: `.report-nav-link.is-active`
```css
.report-nav-link.is-active {
    background-color: #e8f0fe;
    color: #1a73e8;
    border-left-color: #1a73e8;
    font-weight: 600;
}
```

### Count Badge: `.report-nav-count`
```css
.report-nav-count {
    color: #888;
    font-size: 13px;
    font-weight: 400;
}

.report-nav-link.is-active .report-nav-count {
    color: #1a73e8;
}
```

---

## Active State Logic

On the List Item or the `.report-nav-link` container, set the Style Classes expression:

```
"report-nav-link" + If(ModuleList.Current.MaxtelAppId = ActiveMaxtelAppId, " is-active", "")
```

---

## Empty State

If `ModuleList.Length = 0` after fetch, show:

```
Container (class: "report-nav-empty")
└─ Text: "No report modules available"
```

```css
.report-nav-empty {
    padding: 16px;
    color: #888;
    font-size: 13px;
    text-align: center;
}
```

---

## Summary

The block is self-contained:
- Fetches its own data (GetReportModuleList)
- Manages its own active state (ActiveMaxtelAppId)
- Tells the parent what was selected via OnModuleSelected event
- Parent doesn't need to know about module data at all
