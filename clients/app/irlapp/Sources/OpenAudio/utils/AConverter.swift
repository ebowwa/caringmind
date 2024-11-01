//
//  AConverter.swift
//  openaudiostandard
//
//  Created by Elijah Arbee on 10/23/24.
//

import Foundation
import AVFoundation

// MARK: - AudioConverterError

/// Enum representing possible errors during audio conversion.
enum AudioConverterError: Error, LocalizedError {
    case assetInitializationFailed
    case exportSessionCreationFailed
    case unsupportedOutputFormat
    case conversionFailed(String)
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .assetInitializationFailed:
            return "Failed to initialize the audio asset."
        case .exportSessionCreationFailed:
            return "Failed to create the export session."
        case .unsupportedOutputFormat:
            return "The specified output format is unsupported."
        case .conversionFailed(let message):
            return "Conversion failed: \(message)"
        case .fileNotFound:
            return "The specified file was not found."
        }
    }
}

// MARK: - AudioConverter

/// A singleton class responsible for converting audio files between .caf and .wav formats.
/// Future support for .mp3 will be added using the LAME library.
class AudioConverter {
    
    // MARK: - Singleton Instance
    
    /// Shared instance of AudioConverter.
    static let shared = AudioConverter()
    
    // MARK: - Initializer
    
    /// Private initializer to enforce singleton usage.
    private init() {}
    
    // MARK: - Public Conversion Methods
    
    /// Converts a .caf file to .wav format.
    /// - Parameters:
    ///   - sourceURL: URL of the source .caf file.
    ///   - destinationURL: URL where the converted .wav file will be saved.
    /// - Throws: `AudioConverterError` if the conversion fails.
    func convertCAFToWAV(sourceURL: URL, destinationURL: URL) async throws {
        try await convertAudio(sourceURL: sourceURL, destinationURL: destinationURL, outputFileType: .wav)
    }
    
    /// Converts a .wav file to .caf format.
    /// - Parameters:
    ///   - sourceURL: URL of the source .wav file.
    ///   - destinationURL: URL where the converted .caf file will be saved.
    /// - Throws: `AudioConverterError` if the conversion fails.
    func convertWAVToCAF(sourceURL: URL, destinationURL: URL) async throws {
        try await convertAudio(sourceURL: sourceURL, destinationURL: destinationURL, outputFileType: .caf)
    }
    
    // MARK: - Private Conversion Methods
    
    /// General method to convert audio files using AVFoundation.
    /// - Parameters:
    ///   - sourceURL: URL of the source audio file.
    ///   - destinationURL: URL where the converted file will be saved.
    ///   - outputFileType: Desired output file type (e.g., .wav, .caf).
    /// - Throws: `AudioConverterError` if the conversion fails.
    private func convertAudio(sourceURL: URL, destinationURL: URL, outputFileType: AVFileType) async throws {
        let asset = AVURLAsset(url: sourceURL)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw AudioConverterError.exportSessionCreationFailed
        }
        
        exportSession.outputFileType = outputFileType
        exportSession.outputURL = destinationURL
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        if #available(macOS 15, iOS 18, *) {
            // Using async method available in macOS 15+ and iOS 18+
            do {
                try await exportSession.export(to: destinationURL, as: outputFileType, isolation: .none)
            } catch {
                throw AudioConverterError.conversionFailed(error.localizedDescription)
            }
        } else {
            // Fallback for earlier versions using exportAsynchronously
            let exportCompleted = try await withCheckedThrowingContinuation { continuation in
                exportSession.exportAsynchronously {
                    if exportSession.status == .completed {
                        continuation.resume()
                    } else if let error = exportSession.error {
                        continuation.resume(throwing: AudioConverterError.conversionFailed(error.localizedDescription))
                    } else {
                        continuation.resume(throwing: AudioConverterError.conversionFailed("Unknown error during export."))
                    }
                }
            }
            
            guard FileManager.default.fileExists(atPath: destinationURL.path) else {
                throw AudioConverterError.conversionFailed("Output file not found after export.")
            }
        }
    }
}
