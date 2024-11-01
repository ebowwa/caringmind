//
//  TranscriptionManager.swift
//  openaudiostandard
//
//  Created by Elijah Arbee on 10/25/24.
//
// Define a Codable struct to hold transcriptions
import Foundation
import Combine

public struct TranscriptionData: Codable {
    public var transcriptionHistory: [String]
    public var lastTranscribedText: String
    
    public init(transcriptionHistory: [String], lastTranscribedText: String) {
        self.transcriptionHistory = transcriptionHistory
        self.lastTranscribedText = lastTranscribedText
    }
}

public class TranscriptionManager: ObservableObject {
    // Singleton instance
    public static let shared = TranscriptionManager()
    
    // Published properties
    @Published private(set) var transcriptionHistory: [String] = []
    @Published private(set) var lastTranscribedText: String = ""
    
    // Private properties
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Load existing transcriptions via AudioFileManager
        if let loadedData = AudioFileManager.shared.loadTranscriptions() {
            self.transcriptionHistory = loadedData.transcriptionHistory
            self.lastTranscribedText = loadedData.lastTranscribedText
        }
        
        // Listen to transcription updates from RecordingScript
        RecordingScript.shared.transcriptionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transcription in
                self?.handleTranscription(transcription)
            }
            .store(in: &cancellables)
        
        // Observe changes to transcriptionHistory and lastTranscribedText to save automatically via AudioFileManager
        $transcriptionHistory
            .sink { [weak self] _ in
                self?.saveTranscriptions()
            }
            .store(in: &cancellables)
        
        $lastTranscribedText
            .sink { [weak self] _ in
                self?.saveTranscriptions()
            }
            .store(in: &cancellables)
    }
    
    // Handle incoming transcriptions
    private func handleTranscription(_ transcription: String) {
        // If the transcription is final, add it to history
        if RecordingScript.shared.isFinalTranscription {
            if !transcription.isEmpty {
                transcriptionHistory.append(transcription)
                lastTranscribedText = ""
            }
        } else {
            // Update the latest transcription
            lastTranscribedText = transcription
        }
    }
    
    // Public methods to access transcriptions
    public func getTranscriptionHistory() -> [String] {
        return transcriptionHistory
    }
    
    public func getLastTranscribedText() -> String {
        return lastTranscribedText
    }
    
    // MARK: - Persistence Methods (Delegated to AudioFileManager)
    
    /// Saves the current transcriptions using AudioFileManager.
    private func saveTranscriptions() {
        let data = TranscriptionData(transcriptionHistory: transcriptionHistory, lastTranscribedText: lastTranscribedText)
        AudioFileManager.shared.saveTranscriptions(data)
    }
    
    /// Loads the transcriptions using AudioFileManager.
    public func loadTranscriptions() {
        if let loadedData = AudioFileManager.shared.loadTranscriptions() {
            self.transcriptionHistory = loadedData.transcriptionHistory
            self.lastTranscribedText = loadedData.lastTranscribedText
        } else {
            self.transcriptionHistory = []
            self.lastTranscribedText = ""
        }
    }
    
    // MARK: - Sharing Methods
    
    /// Sends transcriptions to the backend.
    public func sendTranscriptions(to url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        let data = TranscriptionData(transcriptionHistory: transcriptionHistory, lastTranscribedText: lastTranscribedText)
        AudioFileManager.shared.sendTranscriptions(data, to: url, completion: completion)
    }
    
    /// Sends a ZIP archive of transcriptions and audio files to the backend.
    public func sendZipOfTranscriptionsAndAudio(to url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        AudioFileManager.shared.sendZipOfTranscriptionsAndAudio(to: url, completion: completion)
    }
}
