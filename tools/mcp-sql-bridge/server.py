import asyncio
import os
import json
import sys
from mcp.server.fastmcp import FastMCP
from playwright.async_api import async_playwright
from bs4 import BeautifulSoup
import pandas as pd

# Initialize FastMCP server
mcp = FastMCP("SQL Sandbox Bridge")

# Configuration
BASE_URL = "https://dev.maxtel.com/sql/"
LOGIN_URL = "https://dev.maxtel.com/myinfoweb/"
USER_DATA_DIR = os.path.expanduser("~/mcp_playwright_profile")

# Module ID Registry
MODULE_REGISTRY = {
    "SALES_UI": 2758
}

@mcp.tool()
async def execute_sandbox_sql(sql_query: str, module_id: int = 2758, wait_time_ms: int = 10000):
    """
    Executes a SQL query in the OutSystems SQL Sandbox for a specific Module.
    - sql_query: The T-SQL query to run.
    - module_id: The ID of the module (default 2758 for SALES_UI).
    - wait_time_ms: Max time to wait for results.
    """
    async with async_playwright() as p:
        # Launch persistent context to keep login session
        context = await p.chromium.launch_persistent_context(
            user_data_dir=USER_DATA_DIR,
            headless=True,
            slow_mo=50
        )
        
        page = await context.new_page()
        
        try:
            # 1. Navigate to Module Execution Page
            exec_url = f"{BASE_URL}Execute.aspx?ModuleId={module_id}"
            await page.goto(exec_url)
            
            # 2. Check for Auth Redirection
            if "myinfoweb" in page.url or await page.query_selector("input[type='password']"):
                return (
                    "AUTH_REQUIRED: Please login manually once. \n"
                    f"1. Open Chrome with profile: {USER_DATA_DIR}\n"
                    f"2. Login at: {LOGIN_URL}\n"
                    "3. Try again once the session is active."
                )

            # 3. Inject SQL into Editor
            # Selector for the SQL Sandbox textarea - based on standard OutSystems pattern
            # Using wait_for_selector to ensure the page is ready
            editor_selector = "textarea[id*='SqlInput'], .sql-editor textarea"
            await page.wait_for_selector(editor_selector)
            
            # Clear and fill
            await page.evaluate(f"document.querySelector(\"{editor_selector}\").value = \"\";")
            await page.fill(editor_selector, sql_query)
            
            # 4. Click Run
            # Common OutSystems button selector
            run_btn_selector = "input[value='Run'], button:has-text('Run'), .btn-run"
            await page.click(run_btn_selector)
            
            # 5. Wait for results table or error
            # OutSystems tables usually have results-wrapper or similar
            try:
                await page.wait_for_selector(".Table_Wrapper, table.ResultsTable", timeout=wait_time_ms)
            except:
                # Check for standard OutSystems error feedback
                error_msg = await page.query_selector(".Feedback_Message_Error")
                if error_msg:
                    return f"SQL_ERROR: {await error_msg.inner_text()}"
                return "TIMEOUT: Results did not appear within the wait time."

            # 6. Scrape results
            content = await page.content()
            soup = BeautifulSoup(content, "html.parser")
            
            # Target the first table in the Results area
            table = soup.select_one(".Table_Wrapper table, table.ResultsTable")
            
            if not table:
                return "Query executed but no result table was found in the output wrapper."
            
            # Convert to Pandas for clean formatting
            # pandas.read_html returns a list of dataframes
            df_list = pd.read_html(str(table))
            if not df_list:
                return "Found a table but could not parse it into data."
                
            df = df_list[0]
            
            # Handle empty result sets
            if df.empty:
                return "Query executed successfully. Result set is empty."
                
            return df.to_json(orient="records", indent=2)

        except Exception as e:
            return f"BRIDGE_ERROR: {str(e)}"
        finally:
            await context.close()

if __name__ == "__main__":
    mcp.run()
