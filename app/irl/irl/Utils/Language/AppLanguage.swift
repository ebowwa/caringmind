//
//  AppLanguage.swift
//  irl
// TODO: ADD HUME LANGUAGE SUPPORT
//  Created by Elijah Arbee on 9/9/24.
//
import Foundation

struct AppLanguage: Codable, Equatable, Hashable {
    let code: String
    let name: String
    let service: [String]?
    
    var isWhisperSupported: Bool {
        return service?.contains("falwhisperSep2024") ?? false
    }

    var isClaudeSupported: Bool {
        return service?.contains("anthropic-claude-3") ?? false
    }
// add support for cohere - aya, gpt4o, gemini, open-source, hume, etc.  maybe modularize this part into its own script i.e IsSupportedLanguage
    func hash(into hasher: inout Hasher) {
        hasher.combine(code)
    }
}

class LanguageManager {
    static let shared = LanguageManager()
    
    private var languages: [AppLanguage] = []
    
    private init() {
        loadLanguages()
    }
    
    private func loadLanguages() {
        // Load languages from `languages.json`
        guard let url = Bundle.main.url(forResource: "languages", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Failed to load languages.json")
            return
        }
        
        do {
            let languageData = try JSONDecoder().decode(LanguageData.self, from: data)
            languages = languageData.languages
        } catch {
            print("Failed to decode languages: \(error)")
        }
    }
    
    // Get the preferred language based on device settings
    func getDefaultLanguage() -> AppLanguage? {
        // Get the user's preferred language codes (e.g., "en-US", "fr")
        let preferredLanguages = Locale.preferredLanguages.map { Locale(identifier: $0).languageCode ?? "en" }
        
        // Find the first match between the user's preferred languages and supported app languages
        for languageCode in preferredLanguages {
            if let matchedLanguage = languages.first(where: { $0.code == languageCode }) {
                return matchedLanguage
            }
        }
        
        // If no match is found, return a fallback language (e.g., English)
        return languages.first(where: { $0.code == "en" })
    }

    func getAllLanguages() -> [AppLanguage] {
        return languages
    }
    
    func getWhisperSupportedLanguages() -> [AppLanguage] {
        return languages.filter { $0.isWhisperSupported }
    }

    func getClaudeSupportedLanguages() -> [AppLanguage] {
        return languages.filter { $0.isClaudeSupported }
    }
    
    func language(forCode code: String) -> AppLanguage? {
        return languages.first { $0.code == code }
    }
    
    func code(forLanguage language: AppLanguage) -> String {
        return language.code
    }
}

private struct LanguageData: Codable {
    let languages: [AppLanguage]
}
