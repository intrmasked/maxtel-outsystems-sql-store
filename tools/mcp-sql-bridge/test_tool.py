import asyncio
from main import execute_sandbox_sql

async def test():
    print("Testing execute_sandbox_sql with SELECT 1...")
    result = await execute_sandbox_sql("SELECT 1 AS TestResult")
    print(f"Result: {result}")

if __name__ == "__main__":
    asyncio.run(test())
