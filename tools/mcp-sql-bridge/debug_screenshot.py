import asyncio
import os
from playwright.async_api import async_playwright

USER_DATA_DIR = os.path.expanduser("~/mcp_playwright_profile")
MODULE_ID = 2758
EXEC_URL = f"https://dev.maxtel.com/sql/Execute.aspx?ModuleId={MODULE_ID}"

async def capture():
    async with async_playwright() as p:
        context = await p.chromium.launch_persistent_context(
            user_data_dir=USER_DATA_DIR,
            headless=True
        )
        page = await context.new_page()
        try:
            await page.goto(EXEC_URL)
            await page.wait_for_timeout(2000)
            await page.screenshot(path="debug_sandbox.png")
            print(f"Screenshot saved to tools/mcp-sql-bridge/debug_sandbox.png")
            print(f"Current URL: {page.url}")
        finally:
            await context.close()

if __name__ == "__main__":
    asyncio.run(capture())
