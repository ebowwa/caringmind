from pydub import AudioSegment
from pydub.utils import which

# Set ffmpeg path explicitly if not found automatically
AudioSegment.converter = which("ffmpeg")

def convert_m4a_to_wav(input_file_path, output_file_path):
    try:
        audio = AudioSegment.from_file(input_file_path, format="m4a")
        audio.export(output_file_path, format="wav")
        print(f"Conversion successful! Saved as {output_file_path}")
    except Exception as e:
        print(f"Error during conversion: {e}")

# Example usage
input_file = "/Users/ebowwa/irl/clients/app/irlapp/Sources/recording_1729986094.469583.m4a"
output_file = "/Users/ebowwa/irl/output_audio.wav"
convert_m4a_to_wav(input_file, output_file)
