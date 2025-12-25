# SQL Sandbox MCP Bridge

A high-performance bridge that allows agentic AI to execute T-SQL queries directly in the OutSystems SQL Sandbox via Playwright and the Model Context Protocol (MCP).

## 🚀 How we got here
We needed a way to verify complex SQL refactors (like Screen 2 - Operating Periods) against real data without manual copy-pasting and CSV downloading. This tool automates the "Sandbox Loop" by injecting SQL, clicking Run, and scraping the results into clean JSON with execution timing and row counts.

## 🛠️ Fresh Install Setup (New Machine)

Follow these steps to set up the bridge:

### 1. Prerequisites
- **Python 3.10+**: Ensure Python is installed.
- **uv**: The bridge uses `uv` for lightning-fast dependency management.
  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ```

### 2. Project Initialization
```bash
cd tools/mcp-sql-bridge
# Synchronize environment and install dependencies
uv sync
# Install Playwright browsers
uv run playwright install chromium
```

### 3. Environment Configuration
The bridge requires OutSystems credentials for automated login. Set them as environment variables:
```bash
export SQL_SANDBOX_USER="your-email@example.com"
export SQL_SANDBOX_PASS="your-password"
```

### 4. MCP Configuration
To use this bridge with Cursor, Claude, or any MCP client, add the following to your `mcp_config.json` (replacing the paths with your actual absolute paths):

```json
{
  "sql-sandbox": {
    "command": "uv",
    "args": [
      "run",
      "--project",
      "/Users/YOUR_USER/Desktop/heziico/sql-store-maxtel/maxtel-outsystems-sql-store/tools/mcp-sql-bridge",
      "python",
      "/Users/YOUR_USER/Desktop/heziico/sql-store-maxtel/maxtel-outsystems-sql-store/tools/mcp-sql-bridge/main.py"
    ],
    "env": {
      "SQL_SANDBOX_USER": "...",
      "SQL_SANDBOX_PASS": "..."
    }
  }
}
```

## 🛠️ Diagnostics
If you encounter issues, run the diagnostic script:
```bash
uv run diagnose_bridge.py
```
This will generate a `diagnose_success.png` or `diagnose_failed.png` to visually verify the flow.

## 📂 Module Registry
- **SALES_UI**: 2758
