# backend/routers/socket/ping.py
from fastapi import APIRouter, WebSocket

router = APIRouter()

@router.websocket("/ws/ping")
async def websocket_ping_endpoint(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            data = await websocket.receive_text()
            if data == "PING":
                await websocket.send_text("PONG")
                print("Received Ping, sent Pong")
            else:
                await websocket.send_text(f"You sent: {data}")
                print(f"Received: {data}")
    except Exception as e:
        print(f"Error: {e}")