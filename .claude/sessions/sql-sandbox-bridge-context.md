# Session: SQL Sandbox MCP Bridge - 2025-12-25

## Original Story/Requirements
Create an MCP bridge (Python + Puppeteer/Playwright) to automate SQL execution in the OutSystems Sandbox. Use `uv` for package management, handle persistent login via a user data directory, and track Module IDs.

## Status
- [ ] Complete / [x] In Progress / [ ] Needs Review
- Current step: Finalizing `pyproject.toml` and server logic.
- Incomplete items: Verification test, handling potential UI selectors for specific Sandbox pages.

## Tables Documentation Created
- N/A (Infrastructure Session)

## Queries Created
- N/A

## Key Decisions
- **Playwright over Puppeteer**: Better Python support (Playwright-Python) and more reliable persistent context handling.
- **UV**: Used for environment isolation and fast dependency resolution.
- **Persistent Profile**: Stored in `~/mcp_playwright_profile` to bypass recurring MFA/Auth challenges after initial manual login.
- **Module Registry**: Stored in both `server.py` and `claude.md` for easy reference.

## Next Steps
1. Verify the `execute_sandbox_sql` selector against the live UI.
2. Test a simple `SELECT 1` through the bridge.
3. Integrate the bridge into the Claude/Cursor MCP settings.

## Notes for Next Session
- Login URL: `https://dev.maxtel.com/myinfoweb/`
- Sandbox Base: `https://dev.maxtel.com/sql/Execute.aspx?ModuleId={id}`
- Default Module: 2758 (SALES_UI)

## Quick Resume
To continue:
1. Ensure `uv run server.py` starts correctly.
2. Check `tools/mcp-sql-bridge/server.py` for selector accuracy.
