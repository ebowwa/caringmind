# File: gemini_config.py
# Contains shared configuration for Gemini API

MODEL_VARIANTS = {
    "gemini-1.5-flash": {
        "description": "Fast and versatile performance across a diverse variety of tasks",
        "inputs": ["audio", "images", "videos", "text"],
        "optimized_for": "Most balanced multimodal tasks balancing performance and cost"
    },
    "gemini-1.5-flash-8b": {
        "description": "High volume and lower intelligence tasks",
        "inputs": ["audio", "images", "videos", "text"],
        "optimized_for": "Lower intelligence, high-frequency tasks"
    },
    "gemini-1.5-pro": {
        "description": "Features for a wide variety of reasoning tasks",
        "inputs": ["audio", "images", "videos", "text"],
        "optimized_for": "Complex reasoning tasks requiring more intelligence"
    },
    "gemini-1.0-pro": {
        "description": "Natural language tasks, multi-turn text and code chat, and code generation",
        "inputs": ["text"],
        "optimized_for": "Natural language and code-related tasks"
    },
    "text-embedding-004": {
        "description": "Measuring the relatedness of text strings",
        "inputs": ["text"],
        "optimized_for": "Text embeddings"
    },
    "aqa": {
        "description": "Providing source-grounded answers to questions",
        "inputs": ["text"],
        "optimized_for": "Question answering"
    }
}

SUPPORTED_LANGUAGES = [
    "ar", "bn", "bg", "zh", "hr", "cs", "da", "nl", "en", "et", "fi",
    "fr", "de", "el", "iw", "hi", "hu", "id", "it", "ja", "ko", "lv",
    "lt", "no", "pl", "pt", "ro", "ru", "sr", "sk", "sl", "es", "sw",
    "sv", "th", "tr", "uk", "vi"
]

SUPPORTED_RESPONSE_MIME_TYPES = ["application/json", "text/plain", "text/x.enum"]
