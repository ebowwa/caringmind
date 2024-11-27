# backend/route/gemini/gemini_audio_handling_noauth.py

import os
import asyncio
from fastapi import APIRouter, UploadFile, File, HTTPException, Query
from fastapi.responses import JSONResponse
from typing import List, Optional, Tuple, Union
from dotenv import load_dotenv
import google.generativeai as genai
import logging
import traceback
from tenacity import retry, stop_after_attempt, wait_exponential
from functools import partial
from .gemini_process_webhook import process_with_gemini_webhook

# Configure logging for this module
logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.DEBUG)

# Load environment variables
load_dotenv()

# Initialize FastAPI router
router = APIRouter()

# Configure Gemini API
google_api_key = os.getenv("GOOGLE_API_KEY")
if not google_api_key:
    logger.critical("GOOGLE_API_KEY not found in environment variables.")
    raise EnvironmentError("GOOGLE_API_KEY not found in environment variables.")

genai.configure(api_key=google_api_key)

@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=4, max=10))
def upload_to_gemini(file_content: bytes, mime_type: Optional[str] = None) -> object:
    try:
        import io
        file_obj = io.BytesIO(file_content)
        logger.debug("Uploading file to Gemini...")
        uploaded_file = genai.upload_file(file_obj, mime_type=mime_type)
        logger.info(f"Successfully uploaded file as: {uploaded_file.uri}")
        return uploaded_file
    except genai.HttpError as e:
        logger.error(f"HTTPError uploading file: {e.response.content}")
        traceback.print_exc()
        raise
    except Exception as e:
        logger.error(f"Unexpected error uploading file: {e}")
        traceback.print_exc()
        raise

async def process_single_file(file: UploadFile) -> object:
    try:
        logger.debug(f"Starting to process file: {file.filename}")
        content = await file.read()
        logger.debug(f"Read {len(content)} bytes from {file.filename}")

        uploaded_file = upload_to_gemini(content, file.content_type)

        logger.debug(f"Uploaded file to Gemini: {uploaded_file.uri}")
        return uploaded_file
    except HTTPException as he:
        raise he
    except Exception as e:
        logger.error(f"Error processing file {file.filename}: {e}")
        traceback.print_exc()
        raise HTTPException(
            status_code=500,
            detail=f"Failed to process file {file.filename}: {str(e)}"
        )

def process_individual_file(
    filename: str,
    uploaded_file: object,
    prompt_type: str,
    model_name: str,
    temperature: float,
    top_p: float,
    top_k: int,
    max_output_tokens: int,
    **kwargs  # Accept additional keyword arguments
) -> Union[Tuple[str, object], Exception]:
    try:
        logger.debug(f"Processing with Gemini webhook for file: {filename}")
        gemini_result = process_with_gemini_webhook(
            uploaded_file,
            prompt_type=prompt_type,
            batch=False,
            model_name=model_name,
            temperature=temperature,
            top_p=top_p,
            top_k=top_k,
            max_output_tokens=max_output_tokens,
            **kwargs  # Pass additional keyword arguments, including text_input
        )
        logger.debug(f"Gemini processing successful for file: {filename}")
        return (filename, gemini_result)
    except Exception as e:
        logger.error(f"Error in Gemini processing for file {filename}: {e}")
        traceback.print_exc()
        return e

@router.post("/process-audio")
async def process_audio(
    files: List[UploadFile] = File(...),
    prompt_type: str = Query("default", description="Type of prompt and schema to use"),
    batch: bool = Query(False, description="Process files in batch if True"),
    model_name: str = Query("gemini-1.5-flash", description="Name of the Gemini model to use"),
    temperature: float = Query(1.0, description="Temperature parameter for generation"),
    top_p: float = Query(0.95, description="Top-p parameter for generation"),
    top_k: int = Query(40, description="Top-k parameter for generation"),
    max_output_tokens: int = Query(8192, description="Maximum output tokens"),
    text_input: Optional[str] = Query(None, description="Additional text input to include in the model request")
):
    supported_mime_types = {
        "audio/wav", "audio/mp3", "audio/aiff",
        "audio/aac", "audio/ogg", "audio/flac"
    }

    if not files:
        logger.warning("No files uploaded in the request.")
        raise HTTPException(status_code=400, detail="No files uploaded.")

    # Validate all files
    for file in files:
        if file.content_type not in supported_mime_types:
            logger.warning(f"Unsupported file type: {file.content_type} for file {file.filename}.")
            raise HTTPException(
                status_code=400,
                detail=f"Unsupported file type: {file.content_type}. Supported types: {supported_mime_types}"
            )

    try:
        # Process files concurrently for uploading
        processing_tasks = [process_single_file(file) for file in files]
        uploaded_files = await asyncio.gather(*processing_tasks, return_exceptions=True)

        # Check for any exceptions in uploaded_files
        errors = []
        valid_uploaded_files = []
        for file, uploaded_file in zip(files, uploaded_files):
            if isinstance(uploaded_file, Exception):
                logger.error(f"Error processing file {file.filename}: {uploaded_file}")
                errors.append({
                    "file": file.filename,
                    "status": "failed",
                    "error": str(uploaded_file)
                })
            else:
                valid_uploaded_files.append((file.filename, uploaded_file))

        if not valid_uploaded_files:
            logger.warning("All file uploads failed.")
            return JSONResponse(content={"results": errors})

        results = errors.copy()

        if batch:
            # Process with Gemini webhook with batch=True
            try:
                logger.debug("Starting batch processing with Gemini webhook.")
                gemini_result = await asyncio.get_event_loop().run_in_executor(
                    None,
                    partial(
                        process_with_gemini_webhook,
                        [uploaded_file for _, uploaded_file in valid_uploaded_files],
                        prompt_type=prompt_type,
                        batch=True,
                        model_name=model_name,
                        temperature=temperature,
                        top_p=top_p,
                        top_k=top_k,
                        max_output_tokens=max_output_tokens,
                        text_input=text_input  # Pass text_input as a keyword argument
                    )
                )
                results.append({
                    "files": [filename for filename, _ in valid_uploaded_files],
                    "status": "processed",
                    "data": gemini_result
                })
                logger.debug("Batch processing with Gemini webhook successful.")
            except Exception as e:
                logger.error(f"Error in Gemini processing (batch): {e}")
                traceback.print_exc()
                raise HTTPException(status_code=500, detail="Gemini processing failed.")
        else:
            # Process each file individually
            processing_tasks = []
            for filename, uploaded_file in valid_uploaded_files:
                task = asyncio.get_event_loop().run_in_executor(
                    None,
                    partial(
                        process_individual_file,
                        filename,
                        uploaded_file,
                        prompt_type,
                        model_name,
                        temperature,
                        top_p,
                        top_k,
                        max_output_tokens,
                        text_input=text_input  # Pass text_input as a keyword argument
                    )
                )
                processing_tasks.append(task)

            individual_results = await asyncio.gather(*processing_tasks, return_exceptions=True)

            for original_file, result in zip(valid_uploaded_files, individual_results):
                filename, _ = original_file
                if isinstance(result, Exception):
                    logger.error(f"Error in Gemini processing for file {filename}: {result}")
                    results.append({
                        "file": filename,
                        "status": "failed",
                        "error": str(result)
                    })
                elif isinstance(result, tuple):
                    fname, gemini_result = result
                    results.append({
                        "file": fname,
                        "status": "processed",
                        "data": gemini_result
                    })
                else:
                    logger.error(f"Unexpected result type for file {filename}: {result}")
                    results.append({
                        "file": filename,
                        "status": "failed",
                        "error": "Unexpected processing result."
                    })

        return JSONResponse(content={"results": results})

    except Exception as e:
        logger.error(f"Unexpected error in process_audio: {e}")
        traceback.print_exc()
        raise HTTPException(
            status_code=500,
            detail="Internal Server Error. Please check the server logs."
        )
