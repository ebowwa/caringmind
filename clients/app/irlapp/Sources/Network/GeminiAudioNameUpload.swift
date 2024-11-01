//
//  GeminiAudioNameUpload.swift
//  irlapp
//
//  Created by Elijah Arbee on 10/30/24.
//

import SwiftUI
import Foundation

struct AudioResponse: Codable {
    let name: String
    let prosody: String
    let feeling: String
}

// Defining MIME types supported by the endpoint
struct AudioUploadMimeType {
    static let wav = "audio/wav"
    static let mp3 = "audio/mp3"
    static let aiff = "audio/aiff"
    static let aac = "audio/aac"
    static let ogg = "audio/ogg"
    static let flac = "audio/flac"
}

import SwiftUI
import Foundation
import Combine
import AVFoundation

class GeminiAudioProcessor: ObservableObject {
    @Published var analysisResult: AudioResponse?
    @Published var errorMessage: String?
    @Published var isRecording: Bool = false

    let audioEngineManager: AudioEngineManager
    private let recordingScript: RecordingScript

    private let networkManager: NetworkManagerProtocol
    private let logger = Logger.shared
    private var cancellables = Set<AnyCancellable>()

    init(audioEngineManager: AudioEngineManager, recordingScript: RecordingScript, networkManager: NetworkManagerProtocol = NetworkManager.shared) {
        self.audioEngineManager = audioEngineManager
        self.recordingScript = recordingScript
        self.networkManager = networkManager

        // Observe the recording state
        recordingScript.isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                self?.isRecording = isRecording
                if !isRecording {
                    self?.handleRecordingFinished()
                }
            }
            .store(in: &cancellables)
    }

    func startRecording() {
        recordingScript.startRecording()
    }

    func stopRecording() {
        recordingScript.stopRecording()
    }

    private func handleRecordingFinished() {
        guard let audioURL = recordingScript.currentRecordingURL() else {
            DispatchQueue.main.async {
                self.errorMessage = "Recording failed: No audio file available."
            }
            return
        }

        // Determine MIME type based on file extension
        let mimeType = self.mimeType(for: audioURL)
        processAudio(fileURL: audioURL, mimeType: mimeType)
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "wav":
            return AudioUploadMimeType.wav
        case "mp3":
            return AudioUploadMimeType.mp3
        case "aiff":
            return AudioUploadMimeType.aiff
        case "aac":
            return AudioUploadMimeType.aac
        case "ogg":
            return AudioUploadMimeType.ogg
        case "flac":
            return AudioUploadMimeType.flac
        default:
            return "application/octet-stream"
        }
    }

    func processAudio(fileURL: URL, mimeType: String) {
        // Assuming the server expects a multipart/form-data request with a single file
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "http://127.0.0.1:9090/gemini/process-audio")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Create the form data
        let formData = self.createFormData(fileURL: fileURL, boundary: boundary, mimeType: mimeType)
        request.httpBody = formData

        let session = URLSession.shared
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Error in request: \(error.localizedDescription)"
                }
                self.logger.error("Error in request: \(error.localizedDescription)")
                return
            }

            if let data = data {
                do {
                    let result = try JSONDecoder().decode(AudioResponse.self, from: data)
                    DispatchQueue.main.async {
                        self.analysisResult = result
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to decode response: \(error.localizedDescription)"
                    }
                    self.logger.error("Failed to decode response: \(error.localizedDescription)")
                }
            }
        }
        task.resume()
    }

    private func createFormData(fileURL: URL, boundary: String, mimeType: String) -> Data {
        var formData = Data()

        // File Data
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        formData.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        formData.append((try? Data(contentsOf: fileURL)) ?? Data())
        formData.append("\r\n".data(using: .utf8)!)

        // Closing Boundary
        formData.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return formData
    }
}
