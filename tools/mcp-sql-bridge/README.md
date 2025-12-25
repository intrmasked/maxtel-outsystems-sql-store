# SQL Sandbox MCP Bridge

A high-performance bridge that allows agentic AI to execute T-SQL queries directly in the OutSystems SQL Sandbox via Playwright and the Model Context Protocol (MCP).

## 🚀 How we got here
We needed a way to verify complex SQL refactors (like Screen 2 - Operating Periods) against real data without manual copy-pasting and CSV downloading. This tool automates the "Sandbox Loop" by injecting SQL, clicking Run, and scraping the results into clean JSON.

## 🛠️ Tech Stack
- **Python + FastMCP**: For the MCP server infrastructure.
- **Playwright**: For headless browser automation and persistent session handling.
- **UV**: For lightning-fast dependency management and execution.
- **BeautifulSoup4 + Pandas**: For robust table scraping and data formatting.

## 📦 Setup & Installation

### 1. Prerequisite: UV
Ensure you have `uv` installed:
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### 2. Browser Setup
Install the Playwright browser engine:
```bash
uv run playwright install chromium
```

### 3. Persistent Login (Crucial)
The sandbox requires authentication. To avoid complex login automation, we use a persistent browser profile. Run this once, log in manually at the redirected page, and close the browser.
```bash
# MacOS Example
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --user-data-dir="$HOME/mcp_playwright_profile" \
  "https://dev.maxtel.com/myinfoweb/"
```

## 🏃 Running the Server

Use `uv run` to start the server immediately:
```bash
uv run server.py
```

## 🛠️ Available Tools

### `execute_sandbox_sql`
Executes a T-SQL query in the sandbox.
- **Arguments**:
  - `sql_query`: The T-SQL string to execute.
  - `module_id`: (Default: 2758) The OutSystems module to run against.
  - `wait_time_ms`: (Default: 10000) How long to wait for table results.

## 📂 Module Registry
Current IDs tracked in `.claude/claude.md`:
- **SALES_UI**: 2758
