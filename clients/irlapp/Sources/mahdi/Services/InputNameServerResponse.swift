// AppManager.swift
// Handles data, audio, and server interactions

// ideally the user audio from the first `name statement` should be saved until confirmed, the reason is that sometimes the ai mistakes the audio and transcription, we want to ask the user to repeat themselves after the user updates the text transcription personally. So server: base on-shot prompt; client app: Audio input #1 + User Name Correction + Audio input #2
// BUG: need server active state bool and need to not discard audio till approved
import Foundation
import AVFoundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
#endif

struct ServerResponse: Codable {
    let name: String
    let prosody: String
    let feeling: String
    let confidence_score: Int
    let confidence_reasoning: String
    let psychoanalysis: String
    let location_background: String  // New field added

    enum CodingKeys: String, CodingKey {
        case name
        case prosody
        case feeling
        case confidence_score
        case confidence_reasoning
        case psychoanalysis
        case location_background
    }
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
    private var isRecording = false
    
    // Backend URL
    private let backendURL = URL(string: "https://8bdb-2a09-bac5-661b-1232-00-1d0-c6.ngrok-free.app/onboarding/v3/process-audio")!
    
    // 1. Start Recording
    func startRecording() {
        #if os(iOS)
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
        #else
        beginRecording()
        #endif
    }
    
    // 2. Begin Recording
    private func beginRecording() {
        #if os(iOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            setupRecording()
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Error setting up audio session: \(error.localizedDescription)"
                self?.showingError = true
            }
        }
        #else
        setupRecording()
        #endif
    }
    
    private func setupRecording() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recordedAudio_\(UUID().uuidString).wav"
        let fileURL = documents.appendingPathComponent(fileName)
        audioFileURL = fileURL
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            isRecording = true
            print("Recording started")
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Error starting recording: \(error.localizedDescription)"
                self?.showingError = true
            }
        }
    }
    
    // 3. Stop Recording and Send Audio
    func stopRecordingAndSendAudio(completion: @escaping (Result<ServerResponse, Error>) -> Void) {
        audioRecorder?.stop()
        isRecording = false
        
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Error deactivating audio session: \(error.localizedDescription)"
                self?.showingError = true
            }
        }
        #endif
        
        print("Recording stopped")
        
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
                    // 3.2.1 Optionally, delete the audio file after successful upload
                    try? FileManager.default.removeItem(at: fileURL)
                    // Note 1: The client-side copy of the audio file is deleted after a successful upload to free up storage.
                case .failure(let error):
                    self?.errorMessage = "Failed to process audio: \(error.localizedDescription)"
                    self?.showingError = true
                    // Note 2: The client-side copy of the audio file is retained if the upload fails, allowing for potential retries.
                    // Note 3: Option to save to bucket exists here
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
                print(serverResponse)
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
    
    #if os(iOS)
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        if type == .began {
            stopRecordingAndSendAudio { _ in }
        } else if type == .ended {
            do {
                try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                startRecording()
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = "Error reactivating audio session: \(error.localizedDescription)"
                    self?.showingError = true
                }
            }
        }
    }
    #endif
}
