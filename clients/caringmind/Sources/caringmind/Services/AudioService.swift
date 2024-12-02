//
//  AudioService.swift
//  mahdi
//
//  Created by Elijah Arbee on 11/22/24.
//

import AVFoundation
import Combine
import Foundation
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif
import SwiftUI

// MARK: - Models

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            self.value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            self.value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            self.value = boolValue
        } else if let stringValue = try? container.decode(String.self) {
            self.value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            self.value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            self.value = dictValue.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode AnyCodable")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded")
            throw EncodingError.invalidValue(value, context)
        }
    }
}

struct ProcessAudioResponse: Codable {
    let results: [AudioResult]?
}

struct AudioResult: Codable, Identifiable {
    var id: UUID
    let file: String       // Made non-optional
    let status: String     // Made non-optional
    let data: [String: AnyCodable]
    let file_uri: String   // Made non-optional
    let stored: Bool       // Made non-optional

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()  // Generate a new UUID during decoding
        file = try container.decode(String.self, forKey: .file)
        status = try container.decode(String.self, forKey: .status)
        data = try container.decode([String: AnyCodable].self, forKey: .data)
        file_uri = try container.decode(String.self, forKey: .file_uri)
        stored = try container.decode(Bool.self, forKey: .stored)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case file
        case status
        case data
        case file_uri
        case stored
    }
}

// MARK: - AudioService

class AudioService: NSObject, ObservableObject, AVAudioRecorderDelegate {
    // MARK: - Published Properties
    @Published var uploadStatus: String = "Idle"
    @Published var liveTranscriptions: [AudioResult] = []
    @Published var historicalTranscriptions: [AudioResult] = []
    @Published var isRecording: Bool = false
    @Published var audioRecorder: AVAudioRecorder?
    @Published var recordingURL: URL?

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let baseURL = Constants.baseURL
    private let pollingInterval: TimeInterval = 10.0 // **Centeralize this into the polling logic**
    private var pollingTimer: Timer? // **Centeralize this into the polling logic**
    private let maxLiveTranscriptions = 50 // What happens to the state/persistance of the transcriptions
    private let maxHistoricalTranscriptions = 100 // What happens to the state/persistance of the transcriptions

    // MARK: - Initialization
    override init() {
        super.init()
        requestAudioPermission()
        startRecording()
        startPolling()
    }

    deinit {
        pollingTimer?.invalidate()
        audioRecorder?.stop()
    }

    // MARK: - Audio Recording Methods

    private func startRecording() {
        #if os(iOS)
        let recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true, options: .notifyOthersOnDeactivation)

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            // Create recording URL
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("recording.m4a")

            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()

            isRecording = true
            recordingURL = audioFilename
            uploadStatus = "Recording..."
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
            uploadStatus = "Recording failed"
        }
        #endif
    }

    private func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        uploadStatus = "Stopped Recording"
        audioRecorder = nil
    }

    private func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - Audio Permission

    private func requestAudioPermission() {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            Task {
                let granted = await AVAudioApplication.requestRecordPermission()
                DispatchQueue.main.async { [weak self] in
                    if granted {
                        self?.startRecording()
                    } else {
                        print("Recording permission denied")
                        self?.uploadStatus = "Audio Recording Permission Denied"
                    }
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.startRecording()
                    } else {
                        print("Recording permission denied")
                        self?.uploadStatus = "Audio Recording Permission Denied"
                    }
                }
            }
        }
        #endif
    }

    // MARK: - Polling Methods *Centeralize*

    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            self?.handlePolling()
        }
        RunLoop.current.add(pollingTimer!, forMode: .common)
    }

    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func handlePolling() {
        guard let fileURL = recordingURL else {
            print("No audio file to upload.")
            return
        }

        stopRecording()
        uploadAudio(files: [fileURL])
        startRecording()
    }

    // MARK: - Upload Audio

    private func uploadAudio(files: [URL]) {
        guard let googleAccountId = KeychainHelper.standard.getGoogleAccountID() else {
            uploadStatus = "Missing Google Account ID"
            return
        }

        let deviceUUID = DeviceUUID.getUUID()
        let promptType = "transcription_v1"
        let batch = "false"

        guard let baseURL = URL(string: baseURL),
              var components = URLComponents(url: baseURL.appendingPathComponent("/production/v1/process-audio"), resolvingAgainstBaseURL: false) else {
            uploadStatus = "Invalid Server URL"
            return
        }

        components.queryItems = [
            URLQueryItem(name: "google_account_id", value: googleAccountId),
            URLQueryItem(name: "device_uuid", value: deviceUUID), // maybe have this and the google account unified so that no need to distinguish between the two
            URLQueryItem(name: "prompt_type", value: promptType), // this is like a system_instruction and will be updated to
            URLQueryItem(name: "batch", value: batch) // TODO: IDK about batches but need this to work too send multiple audio files given the gemini api doesn't have native persistance and is a Stateless API
        ]

        guard let finalURL = components.url else {
            uploadStatus = "Failed to construct URL"
            return
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let httpBody = createMultipartBody(with: files, boundary: boundary)
        request.httpBody = httpBody

        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output -> Data in
                guard let httpResponse = output.response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }

                if !(200..<300).contains(httpResponse.statusCode) {
                    throw NSError(domain: "ServerError",
                                code: httpResponse.statusCode,
                                userInfo: [NSLocalizedDescriptionKey: String(data: output.data, encoding: .utf8) ?? "Unknown error"])
                }
                return output.data
            }
            .decode(type: ProcessAudioResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.uploadStatus = "Upload Failed: \(error.localizedDescription)"
                    }
                },
                receiveValue: { [weak self] response in
                    guard let self = self else { return }

                    if let results = response.results {
                        self.liveTranscriptions.append(contentsOf: results)
                        if self.liveTranscriptions.count > self.maxLiveTranscriptions {
                            self.liveTranscriptions.removeFirst(self.liveTranscriptions.count - self.maxLiveTranscriptions)
                        }
                        self.uploadStatus = "Upload Successful"
                    } else {
                        self.uploadStatus = "Upload Successful but no results"
                    }
                }
            )
            .store(in: &cancellables)
    }

    private func createMultipartBody(with files: [URL], boundary: String) -> Data {
        var body = Data()

        for fileURL in files {
            let filename = fileURL.lastPathComponent
            let mimeType = mimeTypeForPath(path: fileURL.path)

            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"files\"; filename=\"\(filename)\"\r\n")
            body.append("Content-Type: \(mimeType)\r\n\r\n")

            if let fileData = try? Data(contentsOf: fileURL) {
                body.append(fileData)
                body.append("\r\n")
            }
        }

        body.append("--\(boundary)--\r\n")
        return body
    }

    private func mimeTypeForPath(path: String) -> String {
        let pathExtension = URL(fileURLWithPath: path).pathExtension.lowercased()

        switch pathExtension {
        case "aac": return "audio/aac"
        case "flac": return "audio/flac"
        case "aiff": return "audio/aiff"
        case "wav": return "audio/wav"
        case "mp3": return "audio/mp3"
        case "ogg": return "audio/ogg"
        default: return "application/octet-stream"
        }
    }

    // MARK: - AVAudioRecorderDelegate

    #if os(iOS)
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            print("Recording finished successfully")
        } else {
            print("Recording failed")
        }
    }
    #endif
}
