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
            # 1. Start at myinfoweb for full session initialization
            print(f"Navigating to {LOGIN_URL} for session initialization...")
            await page.goto(LOGIN_URL)
            
            # 2. Perform Login if required
            if await page.query_selector("input[type='password']"):
                print("Logging in to myinfoweb...")
                user = os.getenv("SQL_SANDBOX_USER")
                password = os.getenv("SQL_SANDBOX_PASS")
                
                if not user or not password:
                    return (
                        "CREDENTIALS_MISSING: Please set SQL_SANDBOX_USER and SQL_SANDBOX_PASS env vars."
                    )
                
                # myinfoweb selectors
                user_selector = "#WebPatterns_wt9_block_wtUsername_wtEmailInput"
                pass_selector = "#WebPatterns_wt9_block_wtPassword_wtPasswordInput"
                login_btn_selector = "#WebPatterns_wt9_block_wtAction_wtLoginButton"
                
                await page.wait_for_selector(user_selector, timeout=10000)
                await page.fill(user_selector, user)
                await page.fill(pass_selector, password)
                await page.click(login_btn_selector)
                
                # 3. Handle post-login popup ("Select your Business")
                popup_btn_selector = "input[value='Select'], button:has-text('Select'), [id*='wtAction_wt5']"
                try:
                    print("Waiting for post-login popup...")
                    await page.wait_for_selector(popup_btn_selector, timeout=10000)
                    await page.click(popup_btn_selector)
                    print("Popup cleared.")
                    # wait for the dashboard to settle
                    await page.wait_for_load_state("networkidle")
                except:
                    print("No popup detected or already cleared.")

            # 4. Navigate to the SQL Module Page
            module_url = f"{BASE_URL}Execute.aspx?ModuleId={module_id}"
            print(f"Navigating to module: {module_url}")
            await page.goto(module_url, wait_until="networkidle")
            
            # 5. Check if we are still asked for login (some modules force it)
            if "Login" in page.url or await page.query_selector("input[type='password']"):
                print("Module page is asking for login again. Retrying on module page...")
                # Module-specific selectors (sometimes different from myinfoweb)
                m_user_selector = "input[id*='wtUserNameInput']"
                m_pass_selector = "input[id*='wtPasswordInput']"
                m_login_btn = "input[value='Log In'], .btn-login"
                
                if await page.query_selector(m_user_selector):
                    await page.fill(m_user_selector, user)
                    await page.fill(m_pass_selector, password)
                    await page.click(m_login_btn)
                    await page.wait_for_timeout(3000)

            # 6. Inject SQL into Editor
            print("Injecting SQL into CodeMirror...")
            try:
                # First, ensure the CodeMirror container exists
                await page.wait_for_selector(".CodeMirror", timeout=15000)
                
                # Use evaluate to set the value directly in CodeMirror's JS instance
                # This is more robust than keyboard typing for complex UI editors
                await page.evaluate("""(sql) => {
                    const cmElement = document.querySelector('.CodeMirror');
                    if (cmElement && cmElement.CodeMirror) {
                        cmElement.CodeMirror.setValue(sql);
                    } else {
                        // Fallback to textarea if CodeMirror instance not found
                        const textarea = document.querySelector("textarea[id*='SqlInput'], .sql-editor textarea");
                        if (textarea) textarea.value = sql;
                    }
                }""", sql_query)
                print("SQL injected.")
            except Exception as e:
                print(f"Injection warning: {str(e)}. Falling back to keyboard...")
                await page.click(".CodeMirror", force=True)
                await page.keyboard.press("Control+A")
                await page.keyboard.press("Backspace")
                await page.keyboard.type(sql_query)
            
            # 7. Click Run
            print("Clicking Run...")
            # OutSystems often uses specific IDs for the Run link/button
            run_btn_selector = "[id*='wtExecuteLink'], input[value='Run'], button:has-text('Run')"
            await page.click(run_btn_selector)
            
            # 8. Wait for results table or error
            try:
                # Results often appear in Table_Wrapper or ResultsWrapper
                # Using the specific IDs found by the subagent for better stability
                await page.wait_for_selector("[id$='wtResultSetOptions'], .Feedback_Message_Error", timeout=wait_time_ms)
                print("Results or Error detected.")
            except:
                # Take a debug screenshot on timeout
                await page.screenshot(path="timeout_debug.png")
                return "TIMEOUT: Results did not appear. Check timeout_debug.png."

            # 9. Extract Metadata (Rows/Timing)
            metadata = {"row_info": "Unknown", "execution_time": "Unknown"}
            meta_element = await page.query_selector("[id$='wtResultSetOptions']")
            if meta_element:
                meta_text = (await meta_element.inner_text()).strip()
                # Example: "1 of 1 rows | 65 ms | CSV"
                metadata["row_info"] = meta_text
                if "|" in meta_text:
                    parts = meta_text.split("|")
                    metadata["execution_time"] = parts[1].strip() if len(parts) > 1 else "Unknown"

            # 10. Scrape results
            from io import StringIO
            content = await page.content()
            soup = BeautifulSoup(content, "html.parser")
            
            # Target the table in the tabs-content area
            table = soup.select_one(".tabs-content table, [id$='wtTabs_Content'] table, .Table_Wrapper table")
            
            if not table:
                # Check for error message
                error_msg = await page.query_selector(".Feedback_Message_Error")
                if error_msg:
                    return f"SQL_ERROR: {await error_msg.inner_text()}"
                return "Query executed but no result table was found."
            
            # Convert to Pandas for clean formatting
            df_list = pd.read_html(StringIO(str(table)))
            if not df_list:
                return "Found a table but could not parse it into data."
                
            df = df_list[0]
            
            # Handle empty result sets
            if df.empty:
                return json.dumps({
                    "metadata": metadata,
                    "results": "Query executed successfully. Result set is empty."
                }, indent=2)
                
            return json.dumps({
                "metadata": metadata,
                "data": df.to_dict(orient="records")
            }, indent=2)

        except Exception as e:
            return f"BRIDGE_ERROR: {str(e)}"
        finally:
            await context.close()

if __name__ == "__main__":
    mcp.run()
