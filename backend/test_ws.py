import asyncio
import websockets

async def main():
    try:
        async with websockets.connect('ws://127.0.0.1:8002/ws/realtime/test') as ws:
            print("Connected!")
            await ws.send("hello")
    except Exception as e:
        print(f"Failed: {e}")

asyncio.run(main())
