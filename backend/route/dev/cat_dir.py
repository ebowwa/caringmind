# backend/route/dev/cat_dir.py
import os
import json
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from enum import Enum

# Create an APIRouter instance instead of a full FastAPI instance
router = APIRouter()

# Enum for predefined directory paths
class DirectoryEnum(str, Enum):
    backend = 'backend'
    app = 'app'
    openaudiostandard = 'openaudiostandard'

# Map enum values to actual paths
DIRECTORY_PATHS = {
    DirectoryEnum.backend: ['/Users/ebowwa/irl/backend'], # /workspace/irl/backend'
    DirectoryEnum.app: ['/Users/ebowwa/irl/app'], # '/workspace/irl/app'
    DirectoryEnum.openaudiostandard: ['/Users/ebowwa/irl/clients/app/irlapp/Sources/OpenAudio'] # '/workspace/irl/app/IRL/openaudiostandard'
}

# Function to concatenate files in the directory
def concatenate_files_to_json(directory_paths):
    all_files_content = {}

    # Iterate over all provided directory paths
    for directory_path in directory_paths:
        for root, dirs, files in os.walk(directory_path):
            for file in files:
                file_path = os.path.join(root, file)

                # Skip .DS_Store and non-readable files
                if file == ".DS_Store":
                    continue

                try:
                    # Only process files with .json extension or read as plain text
                    if file.endswith('.json'):
                        # Read the file as JSON
                        with open(file_path, 'r', encoding='utf-8') as f:
                            file_content = json.load(f)
                            all_files_content[file] = file_content
                    else:
                        # Read the file as plain text and store it
                        with open(file_path, 'r', encoding='utf-8') as f:
                            file_content = f.read()
                            all_files_content[file] = file_content

                except Exception as e:
                    print(f"Skipping file {file_path} due to error: {e}")
                    continue

    return all_files_content


# Pydantic model for predefined directory options
class DirectoryOption(BaseModel):
    directory: DirectoryEnum


# FastAPI route to concatenate files using predefined directories
@router.post("/concatenate")
def concatenate_directory_files_to_json_predefined(data: DirectoryOption):
    # Get the actual paths associated with the selected directory option
    directory_paths = DIRECTORY_PATHS[data.directory]

    concatenated_content = {}
    for directory_path in directory_paths:
        # Validate the directory path
        if not os.path.isdir(directory_path):
            raise HTTPException(status_code=400, detail=f"Invalid directory path: {directory_path}")
        
        try:
            # Call the concatenation function
            result = concatenate_files_to_json([directory_path])
            concatenated_content.update(result)
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

    return concatenated_content


# Pydantic model for receiving a custom directory path in API requests
class DirectoryPath(BaseModel):
    directory_path: str


# FastAPI route to concatenate files using a custom user-supplied path
@router.post("/concatenate/custom")
def concatenate_directory_files_to_json_custom(data: DirectoryPath):
    directory_path = data.directory_path

    # Validate the provided directory path
    if not os.path.isdir(directory_path):
        raise HTTPException(status_code=400, detail="Invalid directory path")

    try:
        # Call the concatenation function with the user-supplied path
        concatenated_content = concatenate_files_to_json([directory_path])
        return concatenated_content
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

