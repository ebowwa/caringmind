//
//  AFiles.swift
//  openaudiostandard
//
//  Created by Elijah Arbee on 10/28/24.
//

import Foundation
import os.log
import AVFoundation

// MARK: - AudioRecording Struct

/// Represents an audio recording file.
public struct AudioRecording: Identifiable {
    public let id: UUID
    public let url: URL
    public var isSpeechLikely: Bool?
    public var transcription: String? // Added transcription property

    public init(id: UUID = UUID(), url: URL, isSpeechLikely: Bool? = nil, transcription: String? = nil) {
        self.id = id
        self.url = url
        self.isSpeechLikely = isSpeechLikely
        self.transcription = transcription
    }
}

// MARK: - AudioFileManagerProtocol

/// Protocol defining methods for managing audio files and retrieving metadata.
public protocol AudioFileManagerProtocol {
    /// The current device ID associated with the audio files.
    var currentDeviceID: UUID? { get set }

    func getDocumentsDirectory() -> URL
    func updateLocalRecordings() -> [AudioRecording]
    func deleteRecording(_ recording: AudioRecording) throws
    func formattedDuration(_ duration: TimeInterval) -> String
    func formattedFileSize(_ bytes: Int64) -> String
    func formattedDuration(for audioURL: URL) -> String
    func formattedFileSize(for audioURL: URL) -> String
}

// MARK: - AudioFileManager Class

public class AudioFileManager: AudioFileManagerProtocol {
    private let logger: Logger

    /// The current device ID associated with the audio files.
    public var currentDeviceID: UUID?

    /// Dependency injection of Logger instance, with default to Logger.shared
    public init(logger: Logger = .shared) {
        self.logger = logger
    }

    // MARK: - File Management Functions

    /// Retrieves the app's Documents directory URL.
    public func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    /// Updates and retrieves all local audio recordings.
    public func updateLocalRecordings() -> [AudioRecording] {
        let documents = getDocumentsDirectory()
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil, options: [])
            let recordings = files.filter { $0.pathExtension.lowercased() == "m4a" }.map { AudioRecording(url: $0) }
            logger.info("Found \(recordings.count) audio recordings.")
            return recordings.sorted(by: { $0.url.lastPathComponent > $1.url.lastPathComponent })
        } catch {
            logger.error("Failed to list recordings: \(error.localizedDescription)")
            return []
        }
    }

    /// Deletes a specific audio recording.
    /// - Parameter recording: The `AudioRecording` to delete.
    public func deleteRecording(_ recording: AudioRecording) throws {
        do {
            try FileManager.default.removeItem(at: recording.url)
            logger.info("Deleted recording at \(recording.url.path)")
        } catch {
            logger.error("Failed to delete recording at \(recording.url.path): \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Helper Functions for Formatting

    /// Formats a duration in seconds to a "MM:SS" string.
    /// - Parameter duration: The duration in seconds.
    /// - Returns: A formatted string representing the duration.
    public func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Formats a file size in bytes to a human-readable string.
    /// - Parameter bytes: The file size in bytes.
    /// - Returns: A formatted string representing the file size.
    public func formattedFileSize(_ bytes: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// Formats the duration of a specific audio file.
    /// - Parameter audioURL: The URL of the audio file.
    /// - Returns: A formatted string representing the duration.
    public func formattedDuration(for audioURL: URL) -> String {
        let asset = AVURLAsset(url: audioURL)
        let duration = asset.duration
        let durationSeconds = CMTimeGetSeconds(duration)
        let minutes = Int(durationSeconds) / 60
        let seconds = Int(durationSeconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Formats the file size of a specific audio file.
    /// - Parameter audioURL: The URL of the audio file.
    /// - Returns: A formatted string representing the file size.
    public func formattedFileSize(for audioURL: URL) -> String {
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
            if let fileSize = fileAttributes[FileAttributeKey.size] as? Int64 {
                return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            } else {
                logger.warning("Could not retrieve file size for \(audioURL.path)")
                return "Unknown size"
            }
        } catch {
            logger.error("Failed to retrieve file size for \(audioURL.path): \(error.localizedDescription)")
            return "Error"
        }
    }
}
