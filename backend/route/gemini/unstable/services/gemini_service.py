# services/gemini_service.py
import google.generativeai as genai
from typing import Dict, List, Union
import logging
from fastapi import HTTPException
from ..configs.schemas import SchemaManager
from ..utils.json_utils import extract_json_from_response

logger = logging.getLogger(__name__)

class GeminiService:
    def __init__(self, schema_manager: SchemaManager):
        self.schema_manager = schema_manager

    async def process_audio(
        self,
        uploaded_files: Union[List[object], object],
        prompt_type: str = "default",
        batch: bool = False,
        model_name: str = "gemini-1.5-flash",
        temperature: float = 1.0,
        top_p: float = 0.95,
        top_k: int = 40,
        max_output_tokens: int = 8192
    ) -> Dict:
        try:
            config = await self.schema_manager.get_config(prompt_type)
            if not config:
                raise HTTPException(status_code=400, detail=f"Invalid prompt_type: {prompt_type}")

            generation_config = {
                "temperature": temperature,
                "top_p": top_p,
                "top_k": top_k,
                "max_output_tokens": max_output_tokens,
                "response_schema": config["response_schema"],
                "response_mime_type": "application/json",
            }

            model = genai.GenerativeModel(model_name=model_name, generation_config=generation_config)
            
            # Fix: Handle the files correctly based on batch mode
            if batch:
                if isinstance(uploaded_files, list):
                    files = uploaded_files
                else:
                    files = [uploaded_files]
                chat_history = [{"role": "user", "parts": files + [config["prompt_text"]]}]
            else:
                # For single file processing, use the first file only
                file = uploaded_files[0] if isinstance(uploaded_files, list) else uploaded_files
                chat_history = [{"role": "user", "parts": [file, config["prompt_text"]]}]

            logger.debug(f"Processing with chat history: {chat_history}")
            
            # Use async context manager for chat session
            chat = model.start_chat(history=chat_history)
            response = await self._send_message_async(chat, "Process the audio and think deeply")
            
            # Extract and return the JSON response
            result = extract_json_from_response(response.text)
            return result

        except HTTPException as he:
            raise he
        except Exception as e:
            logger.error(f"Unexpected error in process_audio: {e}")
            raise HTTPException(status_code=500, detail=f"Gemini processing failed: {str(e)}")

    async def _send_message_async(self, chat, message: str):
        """Helper method to handle async message sending"""
        try:
            # Use asyncio.to_thread if the operation is blocking
            import asyncio
            response = await asyncio.to_thread(chat.send_message, message)
            return response
        except Exception as e:
            logger.error(f"Error sending message: {e}")
            raise