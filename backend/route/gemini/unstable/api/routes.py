# api/routes.py
from fastapi import APIRouter, File, UploadFile, Query, HTTPException, Depends
from fastapi.responses import JSONResponse
from typing import List, Optional, Dict, Any
import asyncio
import logging
from ..services.auth_service import AuthService
from ..services.audio_service import AudioService
from ..services.gemini_service import GeminiService
from ..services.storage_service import StorageService
from ..configs.schemas.schemas import SchemaManager

logger = logging.getLogger(__name__)

# Initialize services
try:
    schema_manager = SchemaManager()
    auth_service = AuthService()
    audio_service = AudioService()
    gemini_service = GeminiService(schema_manager)
    storage_service = StorageService()
except Exception as e:
    logger.error(f"Failed to initialize services: {e}")
    raise

router = APIRouter()

@router.post("/process-audio")
async def process_audio(
    files: List[UploadFile] = File(...),
    prompt_type: str = Query("transcription_v1", description="Type of prompt to use"),
    batch: bool = Query(False, description="Process files in batch if True"),
    model_name: str = Query("gemini-1.5-flash", description="Gemini model to use"),
    temperature: float = Query(1.0, description="Temperature parameter"),
    top_p: float = Query(0.95, description="Top-p parameter"),
    top_k: int = Query(40, description="Top-k parameter"),
    max_output_tokens: int = Query(8192, description="Maximum output tokens"),
    google_account_id: Optional[str] = Query(None, description="Google Account ID for authentication"),
    device_uuid: Optional[str] = Query(None, description="Device UUID for authentication")
):
    """
    Process audio files with optional authentication and storage.
    
    Returns results with file URIs, processing status, and type predictions.
    If authenticated, also stores results in the database.
    """
    try:
        # Fetch type information from SchemaManager
        schema_config = await schema_manager.get_config(prompt_type)
        type_info = schema_config.get("type", "unknown") if schema_config else "unknown"

        # Verify user if credentials provided
        user_id = await auth_service.verify_user(google_account_id, device_uuid)
        
        # Process files concurrently
        tasks = [audio_service.process_file(file) for file in files]
        uploaded_files = await asyncio.gather(*tasks, return_exceptions=True)

        # Handle results and track valid files
        results = []
        valid_files = []

        for file, result in zip(files, uploaded_files):
            if isinstance(result, Exception):
                logger.error(f"Failed to process file {file.filename}: {result}")
                results.append({
                    "file": file.filename,
                    "status": "failed",
                    "type": type_info,
                    "error": str(result)
                })
            else:
                valid_files.append((file.filename, result))

        if not valid_files:
            logger.warning("No valid files to process")
            return JSONResponse(content={"results": results})

        # Process with Gemini
        try:
            # Extract file objects for Gemini processing
            gemini_file_objects = [f[1]["file_obj"] for f in valid_files]
            
            gemini_results = await asyncio.get_event_loop().run_in_executor(
                None,
                lambda: gemini_service.process_audio(
                    gemini_file_objects,
                    prompt_type=prompt_type,
                    batch=batch,
                    model_name=model_name,
                    temperature=temperature,
                    top_p=top_p,
                    top_k=top_k,
                    max_output_tokens=max_output_tokens
                )
            )

            # Store results if user is authenticated
            if user_id:
                store_tasks = []
                for filename, file_data in valid_files:
                    store_tasks.append(
                        storage_service.store_processed_file(
                            user_id=user_id,
                            file_name=filename,
                            file_uri=file_data["uri"],
                            gemini_result=gemini_results if batch else gemini_results
                        )
                    )
                await asyncio.gather(*store_tasks)
                logger.info(f"Stored results for user {user_id}")

            # Add successful results with URIs and type info
            if batch:
                results.append({
                    "files": [f[0] for f in valid_files],
                    "status": "processed",
                    "type": type_info,
                    "data": gemini_results,
                    "file_uris": [f[1]["uri"] for f in valid_files],
                    "stored": bool(user_id)
                })
            else:
                # For individual file processing
                for filename, file_data in valid_files:
                    results.append({
                        "file": filename,
                        "status": "processed",
                        "type": type_info,
                        "data": gemini_results,
                        "file_uri": file_data["uri"],
                        "stored": bool(user_id)
                    })

        except Exception as e:
            logger.error(f"Gemini processing failed: {e}")
            for filename, _ in valid_files:
                results.append({
                    "file": filename,
                    "status": "failed",
                    "type": type_info,
                    "error": str(e)
                })
            raise HTTPException(status_code=500, detail="Gemini processing failed")

        return JSONResponse(content={"results": results})

    except HTTPException as he:
        # Re-raise HTTP exceptions with their original status codes
        raise he
    except Exception as e:
        logger.error(f"Unexpected error in process_audio endpoint: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Internal Server Error: {str(e)}"
        )

@router.get("/health")
async def health_check():
    """Simple health check endpoint."""
    return {"status": "healthy", "version": "2.0.0"}
