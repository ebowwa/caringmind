# File: backend/index.py **DO NOT OMIT ANYTHING FROM THE FOLLOWING CONTENT, INCLUDING & NOT LIMITED TO COMMENTED NOTES

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.openapi.docs import get_swagger_ui_html  # Import Swagger UI
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
import logging
from route.dev import socket_ping
from route.socket import whisper_tts
from route.post.text.llm_inference.claude import router as claude_router
from route.humeclient import router as hume_router
from route.post.text.embedding.index import router as embeddings_router
# from backend.examples.textEmbeddingRoutev1 import router as embeddings_router  # Embeddings import
# from routers.post.image_generation.FLUXLORAFAL import router as fluxlora_router  # Disabled import
from route.post.image_generation.fast_sdxl import router as sdxl_router  # Fast-SDXL model router
# from route.post.audio.diarization.index import router as diarization_router  # rm 4 gemini
# from backend.examples.openai_post import router as openai_router  # OpenAI (GPT-4o-mini) router
from route.post.text.llm_inference.OpenAIRoute import router as openai_router
from route.post.text.chatgpt_share.index import router as share_oai_chats_router
# from route.post.audio.transcription.falIndex import router as transcription_router removed to use gemini
from route.gemini_flash_series.gemini_index import router as gemini_router
# from route.post.media.upload.Index import router as media_router unneeded
from services.gemini_socket import router as gemini_socket_router
from route.features.user_name_upload import router as user_name_upload_router
from utils.ngrok_utils import start_ngrok 
import ngrok 
from utils.server_manager import ServerManager  # sees If port is open if so closes the port so the server can init
from dotenv import load_dotenv  # Load environment variables from .env
import os
import socket
import subprocess
import signal

# ------------------ Load Environment Variables --------------------
# Load the .env file to read configurations like PORT, NGROK_AUTH, etc.
load_dotenv()

# Flag to toggle Ngrok usage
USE_NGROK = True  # Enable Ngrok by default, can be toggled

# ------------------ FastAPI App Configuration ---------------------
# Create the FastAPI app instance with essential metadata
app = FastAPI(
    title="IRL Backend Service",
    description="A FastAPI backend acting as a proxy to leading AI models.",
    version="0.0.1",
    openapi_url="/openapi.json",  # OpenAPI schema URL
    docs_url=None,  # Disable default docs UI
    redoc_url=None  # Disable default ReDoc UI
)

# ------------------ CORS Middleware -------------------------------
# Add CORS support to allow cross-origin requests from any domain
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow requests from all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allow all HTTP methods (GET, POST, etc.)
    allow_headers=["*"],  # Allow all headers
)

# ------------------ API Routes -------------------------------------

# Socket-based routes (ping, whisper-tts)
app.include_router(socket_ping.router)  # Ping route for WebSocket health check

app.include_router(whisper_tts.router)  # Whisper TTS WebSocket route

# Claude/OpenAI LLM routes
app.include_router(claude_router, prefix="/v3/claude") 

# Hume AI route (speech prosody, emotional analysis)
app.include_router(hume_router, prefix="/api/v1/hume")

# Embeddings route (vectorization for NLP tasks)
app.include_router(embeddings_router) # , prefix="/embeddings")

# Image generation routes
# app.include_router(fluxlora_router, prefix="/api")  # Disabled: FluxLora model
app.include_router(sdxl_router, prefix="/api")  # Fast-SDXL image generation

# Include the transcription router
# app.include_router(transcription_router, prefix="/api",tags=["Transcription"])

# OpenAI GPT model routes (GPT-4o-mini, configurable models)
app.include_router(openai_router, prefix="/LLM")

# Diarization route (speaker separation)
# app.include_router(diarization_router, prefix="/api")

# ChatGPT share conversation route
app.include_router(share_oai_chats_router, prefix="/api/chatgpt")  # New route for ChatGPT share conversations

# app.include_router(media_router, prefix="/media")  # <-- Include media router with a prefix

app.include_router(gemini_router, prefix="/api/gemini")  # <-- Added Gemini router with prefix

app.include_router(gemini_socket_router, prefix="/api/gemini")

app.include_router(user_name_upload_router)

# ------------------ OpenAPI & Swagger UI ---------------------------
# Serve the OpenAPI schema separately
@app.get("/openapi.json", include_in_schema=False)
async def get_openapi():
    return app.openapi()

# Serve Swagger UI at /api/docs
@app.get("/api/docs", include_in_schema=False)
async def custom_swagger_ui():
    return get_swagger_ui_html(
        openapi_url="/openapi.json",
        title="IRL Backend Service API Docs",
        swagger_favicon_url="https://fastapi.tiangolo.com/img/favicon.png"  # Optional custom favicon
    )


# ------------------ Main Program Entry Point -----------------------
if __name__ == "__main__":
    import uvicorn

    # Get the port from environment or use default 9090
    PORT = int(os.getenv("PORT", 9090))

    # Initialize the ServerManager for handling the port
    server_manager = ServerManager(port=PORT)

    # Attempt to kill any process using the same port before launching
    try:
        server_manager.find_and_kill_process()
    except Exception as e:
        print(f"ServerManager Error: {e}")
        exit(1)  # Terminate if port cannot be freed

   # ------------------ Ngrok Setup (Optional) ---------------------
    # If Ngrok is enabled, establish an HTTP tunnel
    if USE_NGROK:
        try:
            ngrok_url = start_ngrok(PORT)
        except Exception as e:
            print(f"Ngrok setup failed: {e}")
            exit(1)

    # ------------------ Start the Uvicorn Server -------------------
    try:
        uvicorn.run(app, host="0.0.0.0", port=PORT)
    except Exception as e:
        print(f"Failed to start the server: {e}")