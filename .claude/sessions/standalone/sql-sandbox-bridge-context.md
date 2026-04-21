# Session: SQL Sandbox MCP Bridge - 2025-12-25

## Original Story/Requirements
Create an MCP bridge (Python + Puppeteer/Playwright) to automate SQL execution in the OutSystems Sandbox. Use `uv` for package management, handle persistent login via a user data directory, and track Module IDs.

## Status
- [x] Complete / [ ] In Progress / [ ] Needs Review
- Current step: Published to Git and verified end-to-end.
- Incomplete items: Ready for Screen 3 refactor.

## Tables Documentation Created
- N/A (Infrastructure Session)

## Queries Created
- N/A

## Key Decisions
- **Automated Login**: Switched from manual profile to automated `myinfoweb` login with popup clearing to ensure stable session transfer.
- **Metadata Extraction**: Captured query timing (e.g. 67ms) and row counts from the UI for performance tracking.
- **Structured JSON**: Changed tool output to JSON with `metadata` and `data` objects.

## Next Steps
1. Start refactoring **Screen 3**.
2. Use the bridge to verify Screen 3 queries.

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
