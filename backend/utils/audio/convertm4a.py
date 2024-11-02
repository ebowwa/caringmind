# backend/utils/audio/convertm4a.py
import os
import mimetypes
import shutil
from typing import Optional, Union
from pydub import AudioSegment
import io
import magic  # Install python-magic for MIME type detection && brew install libmagic


class UnsupportedMIMETypeError(Exception):
    """Exception raised when the audio file has an unsupported MIME type."""
    pass

class FFmpegNotFoundError(Exception):
    """Exception raised when FFmpeg is not installed or not found."""
    pass

class AudioConversionError(Exception):
    """Exception raised when audio conversion fails."""
    pass

class AudioConverter:
    """
    A class to handle audio file validation and conversion to a resource-efficient format.
    
    Supported MIME types:
        - audio/wav
        - audio/mp3
        - audio/aiff
        - audio/aac
        - audio/ogg
        - audio/flac
        - audio/m4a
    """
    
    supported_mime_types = [
        "audio/wav",
        "audio/mp3",
        "audio/aiff",
        "audio/aac",
        "audio/ogg",
        "audio/flac",
        "audio/m4a",   # Added m4a
        "audio/mp4",   # Common MIME type for m4a
    ]
    
    def __init__(self, input_audio: Union[str, io.BytesIO]):
        """
        Initializes the AudioConverter with the input audio file.
        
        Args:
            input_audio (str or io.BytesIO): Path to the audio file or a file-like object.
        
        Raises:
            UnsupportedMIMETypeError: If the audio file's MIME type is not supported.
            FFmpegNotFoundError: If FFmpeg is not installed or not found.
        """
        self.input_audio = input_audio
        self.audio = None
        self.input_mime_type = None
        
        # Verify FFmpeg installation
        if not self._is_ffmpeg_installed():
            raise FFmpegNotFoundError("FFmpeg is not installed or not found in PATH.")
        
        # Load the audio file
        self._load_audio()
    
    def _is_ffmpeg_installed(self) -> bool:
        """
        Checks if FFmpeg is installed and accessible.
        
        Returns:
            bool: True if FFmpeg is installed, False otherwise.
        """
        return shutil.which("ffmpeg") is not None
    
    def _load_audio(self):
        """
        Loads the audio file and validates its MIME type.
        
        Raises:
            UnsupportedMIMETypeError: If the audio file's MIME type is not supported.
            AudioConversionError: If the audio file cannot be loaded.
        """
        try:
            if isinstance(self.input_audio, str):
                # Input is a file path
                if not os.path.isfile(self.input_audio):
                    raise FileNotFoundError(f"Audio file not found at path: {self.input_audio}")
                
                self.input_mime_type, _ = mimetypes.guess_type(self.input_audio)
                if self.input_mime_type not in self.supported_mime_types:
                    # Attempt to detect MIME type using magic
                    self.input_mime_type = self._get_mime_type_from_file(self.input_audio)
                    if self.input_mime_type not in self.supported_mime_types:
                        raise UnsupportedMIMETypeError(f"MIME type '{self.input_mime_type}' is not supported.")
                
                self.audio = AudioSegment.from_file(self.input_audio)
            elif isinstance(self.input_audio, io.BytesIO):
                # Input is a file-like object
                self.input_audio.seek(0)
                audio_bytes = self.input_audio.read()
                self.input_mime_type = self._get_mime_type_from_bytes(audio_bytes)
                
                if self.input_mime_type not in self.supported_mime_types:
                    raise UnsupportedMIMETypeError(f"MIME type '{self.input_mime_type}' is not supported.")
                
                self.audio = AudioSegment.from_file(self.input_audio, format=self._get_format_from_mime(self.input_mime_type))
            else:
                raise TypeError("input_audio must be a file path (str) or a file-like object (io.BytesIO).")
        
        except UnsupportedMIMETypeError:
            raise
        except Exception as e:
            raise AudioConversionError(f"Failed to load audio: {str(e)}")
    
    def _get_mime_type_from_bytes(self, audio_bytes: bytes) -> Optional[str]:
        """
        Attempts to determine the MIME type from audio bytes.
        
        Args:
            audio_bytes (bytes): The audio data in bytes.
        
        Returns:
            Optional[str]: The detected MIME type or None if undetectable.
        """
        mime = magic.Magic(mime=True)
        return mime.from_buffer(audio_bytes)
    
    def _get_mime_type_from_file(self, file_path: str) -> Optional[str]:
        """
        Determines the MIME type of a file using python-magic.
        
        Args:
            file_path (str): Path to the file.
        
        Returns:
            Optional[str]: The detected MIME type or None if undetectable.
        """
        try:
            mime = magic.Magic(mime=True)
            return mime.from_file(file_path)
        except Exception:
            return None
    
    def _get_format_from_mime(self, mime_type: str) -> str:
        """
        Maps MIME types to Pydub format strings.
        
        Args:
            mime_type (str): The MIME type of the audio file.
        
        Returns:
            str: The corresponding format string for Pydub.
        
        Raises:
            ValueError: If the MIME type does not correspond to a known format.
        """
        mime_to_format = {
            "audio/wav": "wav",
            "audio/mp3": "mp3",
            "audio/aiff": "aiff",
            "audio/aac": "aac",
            "audio/ogg": "ogg",
            "audio/flac": "flac",
            "audio/m4a": "m4a",
            "audio/mp4": "mp4",
        }
        format_str = mime_to_format.get(mime_type)
        if not format_str:
            raise ValueError(f"Unsupported MIME type for format mapping: {mime_type}")
        return format_str
    
    def convert_to_mp3(self, output_path: str, bitrate: str = "64k") -> str:
        """
        Converts the loaded audio to MP3 format with the specified bitrate.
        
        Args:
            output_path (str): Path to save the converted MP3 file.
            bitrate (str, optional): The bitrate for the MP3 file (e.g., '64k'). Defaults to '64k'.
        
        Returns:
            str: Path to the converted MP3 file.
        
        Raises:
            AudioConversionError: If the conversion fails.
        """
        try:
            self.audio.export(output_path, format="mp3", bitrate=bitrate)
            return output_path
        except Exception as e:
            raise AudioConversionError(f"Failed to convert audio to MP3: {str(e)}")
    
    def convert_to_ogg(self, output_path: str, bitrate: str = "64k") -> str:
        """
        Converts the loaded audio to OGG format with the specified bitrate.
        
        Args:
            output_path (str): Path to save the converted OGG file.
            bitrate (str, optional): The bitrate for the OGG file (e.g., '64k'). Defaults to '64k'.
        
        Returns:
            str: Path to the converted OGG file.
        
        Raises:
            AudioConversionError: If the conversion fails.
        """
        try:
            self.audio.export(output_path, format="ogg", bitrate=bitrate)
            return output_path
        except Exception as e:
            raise AudioConversionError(f"Failed to convert audio to OGG: {str(e)}")
    
    def convert_to_lowest_resource_format(self, output_path: str, format_priority: list = ["mp3", "ogg"]) -> str:
        """
        Converts the loaded audio to the least resource-consuming format based on the provided priority.
        
        Args:
            output_path (str): Path to save the converted audio file.
            format_priority (list, optional): List of formats in order of preference. Defaults to ['mp3', 'ogg'].
        
        Returns:
            str: Path to the converted audio file.
        
        Raises:
            AudioConversionError: If the conversion fails or no supported format is found.
        """
        for fmt in format_priority:
            try:
                if fmt == "mp3":
                    self.convert_to_mp3(output_path, bitrate="64k")
                elif fmt == "ogg":
                    self.convert_to_ogg(output_path, bitrate="64k")
                else:
                    # Extendable for other formats
                    continue
                return output_path
            except AudioConversionError:
                continue
        raise AudioConversionError("Failed to convert audio to any of the supported formats.")
