//
//  AFiles.swift
//  openaudiostandard
//
//  Created by Elijah Arbee on 10/23/24.
//
// TODO: when batches are sent to the server needs to be contemplated! i will refractor the is speaking parts of the code to make this possible
import Foundation
import ZIPFoundation
import Combine

public class AudioFileManager {
    public static let shared = AudioFileManager()
    
    private init() {}
    
    /// Returns the documents directory URL.
    public func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    /// Updates and returns the list of local recordings.
    public func updateLocalRecordings() -> [AudioRecording] {
        let documents = getDocumentsDirectory()
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil, options: [])
            let recordings = files.filter { $0.pathExtension == "m4a" }.map { AudioRecording(url: $0) }
            return recordings.sorted(by: { $0.url.lastPathComponent > $1.url.lastPathComponent })
        } catch {
            print("Failed to list recordings: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Deletes a specific recording.
    public func deleteRecording(_ recording: AudioRecording) throws {
        try FileManager.default.removeItem(at: recording.url)
    }
    
    /// Formats a duration to a string (MM:SS).
    public func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Formats file size to a readable string.
    public func formattedFileSize(bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB] // Adjust as needed
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - Transcription Persistence
    
    /// Saves transcription data to a JSON file in the documents directory.
    public func saveTranscriptions(_ data: TranscriptionData) {
        let fileURL = getDocumentsDirectory().appendingPathComponent("Transcriptions.json")
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(data)
            try jsonData.write(to: fileURL, options: [.atomicWrite, .completeFileProtection])
            print("Transcriptions saved successfully to \(fileURL.path)")
        } catch {
            print("Failed to save transcriptions: \(error.localizedDescription)")
            // Optionally, handle the error (e.g., notify the user)
        }
    }
    
    /// Loads transcription data from the JSON file in the documents directory.
    public func loadTranscriptions() -> TranscriptionData? {
        let fileURL = getDocumentsDirectory().appendingPathComponent("Transcriptions.json")
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let decodedData = try decoder.decode(TranscriptionData.self, from: data)
            print("Transcriptions loaded successfully from \(fileURL.path)")
            return decodedData
        } catch {
            print("No existing transcriptions found or failed to load: \(error.localizedDescription)")
            // It's okay if the file doesn't exist yet; return nil
            return nil
        }
    }
    
    // MARK: - Sharing Data via POST Requests
    
    /// Sends transcription data to the backend via a POST request.
    public func sendTranscriptions(_ data: TranscriptionData, to url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let jsonData = try? JSONEncoder().encode(data) else {
            completion(.failure(NSError(domain: "EncodingError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode transcription data."])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        // Create a data task
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("Error sending transcriptions: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let responseError = NSError(domain: "ResponseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server."])
                print("Invalid response from server.")
                completion(.failure(responseError))
                return
            }
            
            if (200...299).contains(httpResponse.statusCode) {
                print("Transcriptions sent successfully.")
                completion(.success(()))
            } else {
                let statusError = NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server responded with status code: \(httpResponse.statusCode)"])
                print("Server responded with status code: \(httpResponse.statusCode)")
                completion(.failure(statusError))
            }
        }.resume()
    }
    
    /// Creates and sends a ZIP archive containing audio files and transcription data.
    public func sendZipOfTranscriptionsAndAudio(to url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        let documentsDirectory = getDocumentsDirectory()
        let zipFilename = "TranscriptionsBundle_\(Date().timeIntervalSince1970).zip"
        let zipURL = documentsDirectory.appendingPathComponent(zipFilename)
        
        // Remove existing ZIP file if it exists
        if FileManager.default.fileExists(atPath: zipURL.path) {
            do {
                try FileManager.default.removeItem(at: zipURL)
            } catch {
                print("Failed to remove existing ZIP file: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
        }
        
        // Create ZIP archive
        do {
            // Select specific files to include in the ZIP
            // For example, include all .m4a files and the Transcriptions.json
            let audioFiles = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil, options: []).filter { $0.pathExtension == "m4a" }
            let transcriptionFile = documentsDirectory.appendingPathComponent("Transcriptions.json")
            var filesToZip: [URL] = audioFiles
            if FileManager.default.fileExists(atPath: transcriptionFile.path) {
                filesToZip.append(transcriptionFile)
            }
            
            // Create a ZIP archive selectively
            let archive = try Archive(url: zipURL, accessMode: .create)
            for fileURL in filesToZip {
                let relativePath = fileURL.lastPathComponent
                try archive.addEntry(with: relativePath, fileURL: fileURL, compressionMethod: .deflate)
            }
            
            print("ZIP archive created at \(zipURL.path)")
        } catch {
            print("Failed to create ZIP archive: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }
        
        // Prepare the ZIP file for upload
        guard let zipData = try? Data(contentsOf: zipURL) else {
            print("Failed to read ZIP data.")
            let dataError = NSError(domain: "DataError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read ZIP data."])
            completion(.failure(dataError))
            return
        }
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/zip", forHTTPHeaderField: "Content-Type")
        request.setValue("\(zipData.count)", forHTTPHeaderField: "Content-Length")
        request.httpBody = zipData
        
        // Create a data task
        URLSession.shared.uploadTask(with: request, from: zipData) { data, response, error in
            if let error = error {
                print("Error uploading ZIP archive: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let responseError = NSError(domain: "ResponseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server."])
                print("Invalid response from server.")
                completion(.failure(responseError))
                return
            }
            
            if (200...299).contains(httpResponse.statusCode) {
                print("ZIP archive uploaded successfully.")
                // Optionally, delete the ZIP file after successful upload
                do {
                    try FileManager.default.removeItem(at: zipURL)
                } catch {
                    print("Failed to delete ZIP file after upload: \(error.localizedDescription)")
                    // Not a critical error; proceed
                }
                completion(.success(()))
            } else {
                let statusError = NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server responded with status code: \(httpResponse.statusCode)"])
                print("Server responded with status code: \(httpResponse.statusCode)")
                completion(.failure(statusError))
            }
        }.resume()
    }
    /// Sends a ZIP archive containing only audio files to the backend.
    public func sendAudioFiles(to url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        let documentsDirectory = getDocumentsDirectory()
        let zipFilename = "AudioFilesBundle_\(Date().timeIntervalSince1970).zip"
        let zipURL = documentsDirectory.appendingPathComponent(zipFilename)
        
        // Remove existing ZIP file if it exists
        if FileManager.default.fileExists(atPath: zipURL.path) {
            do {
                try FileManager.default.removeItem(at: zipURL)
            } catch {
                print("Failed to remove existing ZIP file: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
        }
        
        // Create ZIP archive
        do {
            // Collect all audio files (e.g., .m4a files) from the documents directory
            let audioFiles = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil, options: []).filter { $0.pathExtension == "m4a" }
            guard !audioFiles.isEmpty else {
                print("No audio files to zip.")
                completion(.failure(NSError(domain: "NoFilesError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No audio files found to zip."])))
                return
            }
            
            let archive = try Archive(url: zipURL, accessMode: .create)
            for fileURL in audioFiles {
                let relativePath = fileURL.lastPathComponent
                try archive.addEntry(with: relativePath, fileURL: fileURL, compressionMethod: .deflate)
            }
            
            print("ZIP archive with audio files created at \(zipURL.path)")
        } catch {
            print("Failed to create ZIP archive: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }
        
        // Prepare the ZIP file for upload
        guard let zipData = try? Data(contentsOf: zipURL) else {
            print("Failed to read ZIP data.")
            let dataError = NSError(domain: "DataError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read ZIP data."])
            completion(.failure(dataError))
            return
        }
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/zip", forHTTPHeaderField: "Content-Type")
        request.setValue("\(zipData.count)", forHTTPHeaderField: "Content-Length")
        request.httpBody = zipData
        
        // Create a data task
        URLSession.shared.uploadTask(with: request, from: zipData) { data, response, error in
            if let error = error {
                print("Error uploading ZIP archive: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let responseError = NSError(domain: "ResponseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server."])
                print("Invalid response from server.")
                completion(.failure(responseError))
                return
            }
            
            if (200...299).contains(httpResponse.statusCode) {
                print("ZIP archive with audio files uploaded successfully.")
                // Optionally, delete the ZIP file after successful upload
                do {
                    try FileManager.default.removeItem(at: zipURL)
                } catch {
                    print("Failed to delete ZIP file after upload: \(error.localizedDescription)")
                    // Not a critical error; proceed
                }
                completion(.success(()))
            } else {
                let statusError = NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server responded with status code: \(httpResponse.statusCode)"])
                print("Server responded with status code: \(httpResponse.statusCode)")
                completion(.failure(statusError))
            }
        }.resume()
    }

}


// Helper extension to selectively zip items
extension FileManager {
    /// Zips specific files only.
    func zipItem(at sourceURL: URL, to destinationURL: URL, compressionMethod: CompressionMethod, include: [URL]) throws {
        let archive = try Archive(url: destinationURL, accessMode: .create)
        for fileURL in include {
            let relativePath = fileURL.lastPathComponent
            try archive.addEntry(with: relativePath, fileURL: fileURL, compressionMethod: compressionMethod)
        }
    }
}
