// ---------------- MARK: `openaudiostandard` PROTOCOLS ----------------

// MARK: - WebSocketManagerProtocol

public protocol WebSocketManagerProtocol: AnyObject {
    var receivedDataPublisher: AnyPublisher<Data, Never> { get }
    func sendAudioData(_ data: Data)
}

// MARK: - AudioEngineManagerProtocol

public protocol AudioEngineManagerProtocol: AnyObject {
    /// Publisher that emits the current audio level (normalized between 0.0 and 1.0).
    var audioLevelPublisher: AnyPublisher<Float, Never> { get }
    
    /// Publisher that emits audio buffers for processing (e.g., speech recognition).
    var audioBufferPublisher: AnyPublisher<AVAudioPCMBuffer, Never> { get }
    
    /// Indicates whether the audio engine is currently running.
    var isEngineRunning: Bool { get }
    
    /// Starts the audio engine.
    func startEngine()
    
    /// Stops the audio engine.
    func stopEngine()
    
    /// Assigns a WebSocket manager for live audio streaming.
    /// - Parameter manager: An object conforming to `WebSocketManagerProtocol`.
    func assignWebSocketManager(manager: WebSocketManagerProtocol)
    
    /// Starts recording audio to a file.
    func startRecording()
    
    /// Stops recording audio to a file.
    func stopRecording()
}

// MARK: - RecordingManagerProtocol

public protocol RecordingManagerProtocol: AnyObject {
    var isRecording: AnyPublisher<Bool, Never> { get }
    var recordingTime: AnyPublisher<TimeInterval, Never> { get }
    var recordingProgress: AnyPublisher<Double, Never> { get }
    var errorMessage: AnyPublisher<String?, Never> { get }
    
    func startRecording()
    func stopRecording()
    func currentRecordingURL() -> URL?
}

// MARK: - AudioStateProtocol

public protocol AudioStateProtocol: ObservableObject {
    // Recording State
    var isRecording: Bool { get set }
    var isRecordingEnabled: Bool { get set } // Indicates if recording is enabled
    var isBackgroundRecordingEnabled: Bool { get set } // Indicates if background recording is enabled
    
    // Playback State
    var isPlaying: Bool { get set }
    var isPlaybackAvailable: Bool { get set }
    
    // Recording Progress
    var recordingTime: TimeInterval { get set }
    var recordingProgress: Double { get set }
    
    // Current Recording
    var currentRecording: AudioRecording? { get set }
    
    // Error Handling
    var errorMessage: String? { get set }
    
    // Audio Level
    var audioLevelPublisher: AnyPublisher<Float, Never> { get }
    var formattedRecordingTime: String { get }
    
    // Recording Control
    func setupWebSocket(manager: WebSocketManagerProtocol)
    func toggleRecording(manual: Bool)
    func stopRecording()
    
    // Playback Control
    func togglePlayback()
    
    // Recording Management
    func deleteRecording(_ recording: AudioRecording)
    func updateLocalRecordings()
    func fetchRecordings()
    
    // Utility
    func formattedFileSize(bytes: Int64) -> String
    
    // Additional Recording Methods
    func startRecording(manual: Bool)
    func currentRecordingURL() -> URL?
}


public protocol Device: AnyObject {
    var identifier: UUID { get }
    var name: String { get }
    var isConnected: Bool { get set }
    var isRecording: Bool { get set }

    func connect()
    func disconnect()
    func startRecording()
    func stopRecording()
}


// ---------------------------------------------------

//
//  OpenAudioManager.swift
//  openaudiostandard
//
//  Created by Elijah Arbee on 10/23/24.
//
    
import Foundation
import Combine
import AVFoundation

public class OpenAudioManager: NSObject {
    // Singleton instance
    public static let shared = OpenAudioManager()

    // Managers
    private let audioState: AudioState
    private let audioEngineManager: AudioEngineManagerProtocol
    private let soundMeasurementManager: SoundMeasurementManager
    private let audioPlaybackManager: AudioPlaybackManager
    private let locationManager: LocationManager
    private let deviceManager: DeviceManager
    private let transcriptionManager: TranscriptionManager // New Transcription Manager
    private let recordingScript: RecordingScript // Shared RecordingScript

    // Initializer
    private override init() {
        self.audioState = AudioState.shared
        self.audioEngineManager = AudioEngineManager.shared
        self.soundMeasurementManager = SoundMeasurementManager.shared
        self.audioPlaybackManager = AudioPlaybackManager()
        self.locationManager = LocationManager.shared
        self.deviceManager = DeviceManager.shared
        self.transcriptionManager = TranscriptionManager.shared // Initialize TranscriptionManager
        self.recordingScript = RecordingScript.shared // Assuming RecordingScript is a singleton
        super.init()
    }

    // Public methods to interact with the SDK
    public func startRecording(manual: Bool = false) {
        audioState.startRecording(manual: manual)
        recordingScript.startRecording()
    }

    public func stopRecording() {
        audioState.stopRecording()
        recordingScript.stopRecording()
    }

    public func togglePlayback() {
        audioState.togglePlayback()
    }

    public func startStreaming() {
        audioEngineManager.startEngine()
    }

    public func stopStreaming() {
        audioEngineManager.stopEngine()
    }

    public func setupWebSocket(url: URL) {
        let webSocketManager = WebSocketManager(url: url)
        audioState.setupWebSocket(manager: webSocketManager)
        audioEngineManager.assignWebSocketManager(manager: webSocketManager)
    }
}
