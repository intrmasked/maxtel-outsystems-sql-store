import asyncio
import os
from playwright.async_api import async_playwright

USER_DATA_DIR = os.path.expanduser("~/mcp_playwright_profile")
MODULE_ID = 2758
BASE_URL = "https://dev.maxtel.com/sql/"
LOGIN_URL = "https://dev.maxtel.com/myinfoweb/"

async def diagnose():
    async with async_playwright() as p:
        print(f"🚀 Using profile: {USER_DATA_DIR}")
        context = await p.chromium.launch_persistent_context(
            user_data_dir=USER_DATA_DIR,
            headless=True
        )
        page = await context.new_page()
        
        try:
            print(f"🌐 Navigating to: {LOGIN_URL}")
            await page.goto(LOGIN_URL)
            
            # Diagnostic 1: Auth check on myinfoweb
            if await page.query_selector("input[type='password']"):
                print("⚠️ STATUS: AUTH_REQUIRED on myinfoweb.")
                
                user = os.getenv("SQL_SANDBOX_USER")
                password = os.getenv("SQL_SANDBOX_PASS")
                
                if user and password:
                    print("🤖 Attempting automated login to myinfoweb...")
                    user_selector = "#WebPatterns_wt9_block_wtUsername_wtEmailInput"
                    pass_selector = "#WebPatterns_wt9_block_wtPassword_wtPasswordInput"
                    login_btn_selector = "#WebPatterns_wt9_block_wtAction_wtLoginButton"
                    
                    await page.wait_for_selector(user_selector, timeout=10000)
                    await page.fill(user_selector, user)
                    await page.fill(pass_selector, password)
                    await page.click(login_btn_selector)
                    
                    # Diagnostic 2: Popup check
                    print("Waiting for post-login popup...")
                    popup_btn_selector = "input[value='Select'], button:has-text('Select'), [id*='wtAction_wt5']"
                    try:
                        await page.wait_for_selector(popup_btn_selector, timeout=10000)
                        await page.click(popup_btn_selector)
                        print("✅ STATUS: POPUP CLEARED.")
                        await page.wait_for_load_state("networkidle")
                    except:
                        print("ℹ️ STATUS: NO POPUP DETECTED.")
                else:
                    print("❌ STATUS: No credentials found in ENV.")
            else:
                print("✅ STATUS: ALREADY AUTHENTICATED on myinfoweb.")

            # Diagnostic 3: Navigate to Module
            module_url = f"https://dev.maxtel.com/sql/Execute.aspx?ModuleId={MODULE_ID}"
            print(f"🌐 Navigating to module: {module_url}")
            await page.goto(module_url, wait_until="networkidle")
            
            # Check for module-specific login
            if "Login" in page.url or await page.query_selector("input[type='password']"):
                print("⚠️ STATUS: MODULE ASKING FOR LOGIN. Internal session transfer might be slow.")
            
            # Final check for Editor
            print("Searching for SQL Editor...")
            editor_selector = "textarea[id*='SqlInput'], .sql-editor textarea, .CodeMirror textarea"
            try:
                await page.wait_for_selector(editor_selector, timeout=15000)
                print("✅ STATUS: SQL EDITOR READY.")
                await page.screenshot(path="diagnose_success.png")
                print("Saved screenshot: diagnose_success.png")
            except:
                print("❌ STATUS: SQL EDITOR NOT FOUND.")
                await page.screenshot(path="diagnose_failed.png")
                print("Saved screenshot: diagnose_failed.png")
                    
        except Exception as e:
            print(f"💥 ERROR: {str(e)}")
        finally:
            await context.close()

if __name__ == "__main__":
    asyncio.run(diagnose())
