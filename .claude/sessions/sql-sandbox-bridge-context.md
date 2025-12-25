# Session: SQL Sandbox MCP Bridge - 2025-12-25

## Original Story/Requirements
Create an MCP bridge (Python + Puppeteer/Playwright) to automate SQL execution in the OutSystems Sandbox. Use `uv` for package management, handle persistent login via a user data directory, and track Module IDs.

## Status
- [x] Complete / [ ] In Progress / [ ] Needs Review
- Current step: Verified automated login and SQL editor detection.
- Incomplete items: Integration into Claude/Cursor MCP settings.

## Tables Documentation Created
- N/A (Infrastructure Session)

## Queries Created
- N/A

## Key Decisions
- **Automated Login**: Switched from manual profile to automated `myinfoweb` login with popup clearing to ensure stable session transfer.
- **Environment Variables**: Moved to `SQL_SANDBOX_USER` and `SQL_SANDBOX_PASS` for secure credential management.
- **Single Session**: Ensured navigation from login to module happens in one persistent context.

## Next Steps
1. Verify result scraping with a `SELECT 1` test.
2. Hook up the MCP server to the IDE/Claude.
3. Start refactoring Screen 3.

## Quick Resume
To continue:
1. Run `SQL_SANDBOX_USER="..." SQL_SANDBOX_PASS="..." uv run main.py` to start the server.
2. Test tool execution via `test_tool.py`.

## Notes for Next Session
- Login URL: `https://dev.maxtel.com/myinfoweb/`
- Sandbox Base: `https://dev.maxtel.com/sql/Execute.aspx?ModuleId={id}`
- Default Module: 2758 (SALES_UI)

## Quick Resume
To continue:
1. Ensure `uv run server.py` starts correctly.
2. Check `tools/mcp-sql-bridge/server.py` for selector accuracy.
