// AppManager.swift
// Handles data, audio, and server interactions
// working! add a back button for name corrections.
// console log the results of prosody & feeling

import Foundation
import AVFoundation
import Combine
import SwiftUI
import UniformTypeIdentifiers // Import the UniformTypeIdentifiers framework

struct ServerResponse: Codable {
    let name: String
    let prosody: String
    let feeling: String
}

class AppManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    // Published properties for error handling
    @Published var showingError: Bool = false
    @Published var errorMessage: String?
    
    // Data handling
    private var userName: String = ""
    
    func setUserName(_ name: String) {
        userName = name
    }
    
    func getUserName() -> String {
        return userName
    }
    
    // Audio handling
    private var audioRecorder: AVAudioRecorder?
    private var audioFileURL: URL?
    
    // Backend URL
    private let backendURL = URL(string: "https://cdd2-5-187-27-20.ngrok-free.app/process-audio")! // Updated to your provided backend URL
    
    // 1. Start Recording
    func startRecording() {
        // 1.1 Request permission to record
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.beginRecording()
                } else {
                    self?.errorMessage = "Microphone access denied."
                    self?.showingError = true
                }
            }
        }
    }
    
    // 2. Begin Recording
    private func beginRecording() {
        // 2.1 Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
    
            // 2.2 Define the audio file URL with .wav extension
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "recordedAudio_\(UUID().uuidString).wav"
            let fileURL = documents.appendingPathComponent(fileName)
            audioFileURL = fileURL
    
            // 2.3 Define settings for the recorder to use WAV format
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false
            ]
    
            // 2.4 Initialize and prepare the recorder
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
    
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Failed to start recording: \(error.localizedDescription)"
                self?.showingError = true
            }
        }
    }
    
    // 3. Stop Recording and Send Audio
    func stopRecordingAndSendAudio(completion: @escaping (Result<ServerResponse, Error>) -> Void) {
        // 3.1 Stop the recorder
        audioRecorder?.stop()
    
        guard let fileURL = audioFileURL else {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Audio file URL is missing."
                self?.showingError = true
            }
            completion(.failure(NSError(domain: "AppManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Audio file URL is missing."])))
            return
        }
    
        // 3.2 Upload the WAV file to the backend
        uploadAudio(fileURL: fileURL) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    completion(.success(response))
                    // Optionally, delete the audio file after successful upload
                    try? FileManager.default.removeItem(at: fileURL)
                case .failure(let error):
                    self?.errorMessage = "Failed to process audio: \(error.localizedDescription)"
                    self?.showingError = true
                    completion(.failure(error))
                }
            }
        }
    }
    
    // 4. Upload Audio to Backend
    private func uploadAudio(fileURL: URL, completion: @escaping (Result<ServerResponse, Error>) -> Void) {
        // 4.1 Create the URLRequest
        var request = URLRequest(url: backendURL)
        request.httpMethod = "POST"
    
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    
        // 4.2 Create multipart form data
        var body = Data()
    
        // 4.3 Add file data
        let filename = fileURL.lastPathComponent
        let mimeType = mimeTypeForPath(path: fileURL.path)
        
        print("Uploading file: \(filename) with MIME type: \(mimeType)") // Logging
    
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        do {
            let fileData = try Data(contentsOf: fileURL)
            body.append(fileData)
        } catch {
            completion(.failure(error))
            return
        }
        body.append("\r\n")
    
        // 4.4 Close the boundary
        body.append("--\(boundary)--\r\n")
    
        // 4.5 Set the body
        request.httpBody = body
    
        // 4.6 Create and start the upload task
        let session = URLSession.shared
        let task = session.dataTask(with: request) { data, response, error in
            // Handle response
            if let error = error {
                completion(.failure(error))
                return
            }
    
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "AppManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server."])))
                return
            }
    
            guard (200...299).contains(httpResponse.statusCode) else {
                // Log the response body for debugging
                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    print("Server Error Response: \(responseBody)")
                }
                let message = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                completion(.failure(NSError(domain: "AppManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])))
                return
            }
    
            // Ensure data is not nil
            guard let data = data else {
                completion(.failure(NSError(domain: "AppManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received from server."])))
                return
            }
    
            // Decode the JSON response
            do {
                let decoder = JSONDecoder()
                let serverResponse = try decoder.decode(ServerResponse.self, from: data)
                completion(.success(serverResponse))
            } catch {
                completion(.failure(error))
            }
        }
    
        task.resume()
    }
    
    // 5. Helper to determine MIME type based on file extension using UniformTypeIdentifiers
    private func mimeTypeForPath(path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let pathExtension = url.pathExtension.lowercased()
    
        // 5.1. Explicitly handle .wav files
        if pathExtension == "wav" {
            return "audio/wav"
        }
    
        // 5.2. Handle other file types using UTType
        if let utType = UTType(filenameExtension: pathExtension),
           let mimeType = utType.preferredMIMEType {
            return mimeType
        }
        return "application/octet-stream"
    }
}

// 6. Extension to append Data easily
extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
