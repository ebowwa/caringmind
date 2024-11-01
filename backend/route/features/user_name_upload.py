# app/routers/gemini_router.py
# using gemini
import os
from fastapi import APIRouter, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
from dotenv import load_dotenv
import google.generativeai as genai
from google.ai.generativelanguage_v1beta.types import content
import json

# Load environment variables from .env
load_dotenv()

router = APIRouter()

# Configure Gemini with the API key
google_api_key = os.getenv("GOOGLE_API_KEY")
if not google_api_key:
    raise EnvironmentError("GOOGLE_API_KEY not found in environment variables.")

genai.configure(api_key=google_api_key)


def upload_to_gemini(file_path: str, mime_type: str = None):
    """
    Uploads the given file to Gemini.

    Args:
        file_path (str): Path to the file to upload.
        mime_type (str, optional): MIME type of the file. Defaults to None.

    Returns:
        Uploaded file object.
    """
    try:
        uploaded_file = genai.upload_file(file_path, mime_type=mime_type)
        print(f"Uploaded file '{uploaded_file.display_name}' as: {uploaded_file.uri}")
        return uploaded_file
    except Exception as e:
        print(f"Error uploading file: {e}")
        raise


@router.post("/process-audio")
async def process_audio(file: UploadFile = File(...)):
    """
    Endpoint to upload an audio file, process it with Gemini, and return the analysis.

    Args:
        file (UploadFile): The audio file to process.

    Returns:
        JSONResponse: The analysis result from Gemini.
    """
    # Validate MIME type
    supported_mime_types = [
        "audio/wav",
        "audio/mp3",
        "audio/aiff",
        "audio/aac",
        "audio/ogg",
        "audio/flac",
    ]
    if file.content_type not in supported_mime_types:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type: {file.content_type}. Supported types: {supported_mime_types}",
        )

    try:
        # Save the uploaded file temporarily
        temp_file_path = f"/tmp/{file.filename}"
        with open(temp_file_path, "wb") as temp_file:
            content_bytes = await file.read()
            temp_file.write(content_bytes)

        # Upload the file to Gemini
        uploaded_file = upload_to_gemini(temp_file_path, mime_type=file.content_type)

        # Define the generation configuration without the 'enum' key
        generation_config = {
            "temperature": 1,
            "top_p": 0.95,
            "top_k": 64,
            "max_output_tokens": 8192,
            "response_schema": content.Schema(
                type=content.Type.OBJECT,
                required=["name", "prosody", "feeling"],
                properties={
                    "name": content.Schema(
                        type=content.Type.STRING,
                        description="The user's full name.",
                    ),
                    "prosody": content.Schema(
                        type=content.Type.STRING,
                        description="An analysis of the user's speech characteristics, including pronunciation and any noticeable inflections.",
                    ),
                    "feeling": content.Schema(
                        type=content.Type.STRING,
                        description="An interpretation of the user's emotional tone based on their speech pattern.",
                    ),
                },
            ),
            "response_mime_type": "application/json",
        }

        # Create the model
        model = genai.GenerativeModel(
            model_name="gemini-1.5-flash",
            generation_config=generation_config,
        )

        # Prepare the chat session history
        chat_history = [
            {
                "role": "user",
                "parts": [
                    uploaded_file,
                    (
                        "Imagine onboarding as an exploratory field where speech prosody and name "
                        "pronunciation reveal aspects of personal identity, emotions, and cultural "
                        "dynamics. How could analyzing a user’s pronunciation and tone from the way "
                        "they say their name create insights into their self-perception or confidence?\n"
                        "As the user sets up their account, this onboarding step is an opportunity to "
                        "capture their unique identity through the way they say their name. Pay close "
                        "attention to how they pronounce and emphasize their name, as it can reflect "
                        "personal, cultural, and emotional nuances. Be concise yet thoughtful.\n\n"
                        "Follow these steps, but be sure to take context from the user's accent to be "
                        "triple sure you have transcribed correctly:\n"
                        "1.) Transcribe just the user's complete name\n"
                        "2.) Analyze the audio to determine what the user's speech prosody to their name "
                        "says about them - extreme inference; capture every detail\n"
                        "3.) Analyze how the user feels about saying their name for this experience\n\n"
                        "Be sure to be mindful of user dynamics in pronunciation\n\n"
                        "The user was prompted to say `{greeting}, I'm {full_name}`\n\n"
                        "Consider this onboarding as akin to setting up a human playable character (HPC) "
                        "in a role-playing game. Just as an HPC has defining attributes—such as speech, "
                        "personality, and behavioral cues—capturing a user’s unique pronunciation, tone, "
                        "and accent patterns reveals underlying aspects of their personality and comfort "
                        "level.\n\n"
                        "Follow these steps, mindful of the user dynamics and context from their accent to "
                        "ensure accurate transcription:\n\n"
                        "Transcribe the user’s complete name: Focus on capturing every sound and inflection "
                        "to reflect the authenticity of their identity, similar to the way a game captures an "
                        "HPC’s unique dialogue choices.\n\n"
                        "Analyze the user’s speech prosody to uncover nuances in identity:\n\n"
                        "Treat prosody patterns (tone, rhythm, emphasis) like the “character traits” of the "
                        "HPC, which might hint at confidence, pride, or cultural background. Capture every "
                        "detail, considering how tone and emphasis reveal depth, much like layers in "
                        "character development.\n\n"
                        "Evaluate how the user feels about saying their name for this experience:\n\n"
                        "Observe the “emotional response” layer of the HPC analogy: Does their tone suggest "
                        "comfort or hesitation in saying their name? Infer if any detected hesitancy reflects "
                        "uncertainty or if it could stem from the novelty of the interaction, enhancing the "
                        "authenticity of the onboarding experience.\n\n"
                        "Remember: Analyze speech patterns to build a personalized experience, respecting the "
                        "individuality and nuances within each user’s “character profile.”"
                    ),
                ],
            },
        ]

        # Start the chat session with the prepared history
        chat_session = model.start_chat(history=chat_history)

        # Send the message to Gemini
        response = chat_session.send_message("INSERT_INPUT_HERE")  # Replace with actual input if needed

        # Clean up the temporary file
        os.remove(temp_file_path)

        # Parse the JSON response from Gemini
        try:
            # Assuming the response.text contains JSON data
            result = response.text.strip("```json\n").rstrip("```")
            parsed_result = json.loads(result)
        except json.JSONDecodeError as e:
            raise HTTPException(status_code=500, detail=f"Failed to parse Gemini response: {e}")

        # Return the parsed response
        return JSONResponse(content=parsed_result)

    except Exception as e:
        print(f"Error processing audio: {e}")
        raise HTTPException(status_code=500, detail=str(e))


"""
# Example curl 

curl -X POST "http://127.0.0.1:9090/gemini/process-audio" \
  -H "accept: application/json" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@/Users/ebowwa/Desktop/Recorded_Audio_October_27_2024_9_59PM.ogg;type=audio/ogg"
"""

# REFRACTORING TASKS: RESUABLE UTILS, FUCNTIONS, CLASSES, ENUMS, ETC - OFC WE WILL USE THE GEMINI FOR MUCH MORE THAN USER NAME UPLOAD'S.. AND WE DONT WANT A CLUTTERED REDUNDANT CODEBASE