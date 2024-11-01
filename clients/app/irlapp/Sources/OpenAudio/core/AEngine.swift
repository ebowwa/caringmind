// AudioEngineManager.swift
// openaudiostandard
//
// Created by Elijah Arbee on 10/23/24.

import Foundation
import Combine
import AVFoundation

// MARK: - AudioEngineManagerProtocol

/// A protocol defining the interface for managing the audio engine.
public protocol AudioEngineManagerProtocol: AnyObject {
    /// Publisher that emits the current audio level (normalized between 0.0 and 1.0).
    var audioLevelPublisher: AnyPublisher<Float, Never> { get }
    
    /// Publisher that emits audio buffers for processing (e.g., speech recognition).
    var audioBufferPublisher: AnyPublisher<AVAudioPCMBuffer, Never> { get }
    
    /// Indicates whether the audio engine is currently running.
    var isEngineRunning: Bool { get }
    
    /// Exposes the URL of the current audio file being recorded.
    var currentAudioFileURL: URL? { get }
    
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

protocol AudioEngineManagerDelegate: AnyObject {
    func audioEngineManager(_ manager: AudioEngineManager, didFailWithError error: Error)
}


public class AudioEngineManager: NSObject, AudioEngineManagerProtocol {
    weak var delegate: AudioEngineManagerDelegate?

    // MARK: - Subjects
    
    private let audioLevelSubject = PassthroughSubject<Float, Never>()
    public var audioLevelPublisher: AnyPublisher<Float, Never> {
        audioLevelSubject.eraseToAnyPublisher()
    }
    
    private let audioBufferSubject = PassthroughSubject<AVAudioPCMBuffer, Never>()
    public var audioBufferPublisher: AnyPublisher<AVAudioPCMBuffer, Never> {
        audioBufferSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Properties
    
    public private(set) var isEngineRunning: Bool = false
    public let audioEngine = AVAudioEngine()
    private weak var webSocketManager: WebSocketManagerProtocol?
    private let audioBufferSize: AVAudioFrameCount = 1024
    
    // Recording properties
    private var audioFile: AVAudioFile?
    private var audioFilename: URL?
    private var recordingStartTime: Date?
    private let maxRecordingDuration: TimeInterval = 3600 // 1 hour
    
    // Expose currentAudioFileURL
    public var currentAudioFileURL: URL? {
        return audioFilename
    }
    
    // MARK: - Dependencies
    
    private let audioFileManager: AudioFileManagerProtocol
    private let bufferProcessor: AudioBufferProcessorProtocol
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initializes the AudioEngineManager with required dependencies.
    /// - Parameters:
    ///   - audioFileManager: An instance conforming to `AudioFileManagerProtocol`.
    ///   - bufferProcessor: An instance conforming to `AudioBufferProcessorProtocol`.
    public init(audioFileManager: AudioFileManagerProtocol,
                bufferProcessor: AudioBufferProcessorProtocol) {
        self.audioFileManager = audioFileManager
        self.bufferProcessor = bufferProcessor
        super.init()
        
        // Subscribe to buffer processor's publishers and relay to own subjects
        self.bufferProcessor.audioLevelPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.audioLevelSubject.send(level)
            }
            .store(in: &cancellables)
        
        self.bufferProcessor.audioBufferPublisher
            .sink { [weak self] buffer in
                self?.audioBufferSubject.send(buffer)
            }
            .store(in: &cancellables)
        
        // Optionally assign VAD if implemented
    }
    
    /// Assigns the WebSocket manager for live streaming.
    /// - Parameter manager: An instance conforming to `WebSocketManagerProtocol`.
    public func assignWebSocketManager(manager: WebSocketManagerProtocol) {
        self.webSocketManager = manager
        self.bufferProcessor.assignWebSocketManager(manager: manager)
    }
    
    /// Starts the audio engine for live streaming and real-time processing.
    public func startEngine() {
        if isEngineRunning {
            print("[AudioEngineManager] Audio engine is already running.")
            return
        }

        // Configure the audio session before starting the engine
        let audioSessionResult = AVAudioSessionManager.shared.configureAudioSession()
        switch audioSessionResult {
        case .success():
            break
        case .failure(let error):
            print("[AudioEngineManager] Failed to configure audio session: \(error.localizedDescription)")
            delegate?.audioEngineManager(self, didFailWithError: error)
            return
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Initialize audio file
        initializeAudioFile()

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: audioBufferSize, format: inputFormat) { [weak self] (buffer, time) in
            guard let self = self else { return }
            self.bufferProcessor.processAudioBuffer(buffer: buffer, time: time)

            // Write buffer to audio file
            do {
                try self.audioFile?.write(from: buffer)
            } catch {
                print("[AudioEngineManager] Error writing buffer to file: \(error.localizedDescription)")
            }
        }

        do {
            try audioEngine.start()
            isEngineRunning = true
            print("[AudioEngineManager] Audio engine started.")
        } catch {
            print("[AudioEngineManager] Failed to start audio engine: \(error.localizedDescription)")
            delegate?.audioEngineManager(self, didFailWithError: error)
        }
    }
    
    /// Stops the audio engine.
    public func stopEngine() {
        if !isEngineRunning {
            print("[AudioEngineManager] Audio engine is not running.")
            return
        }
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        isEngineRunning = false
        
        // Close audio file
        audioFile = nil
        audioFilename = nil
        recordingStartTime = nil
        
        print("[AudioEngineManager] Audio engine stopped.")
        
        // Deactivate the audio session if no other components are using it
        let deactivateResult = AVAudioSessionManager.shared.deactivateAudioSession()
        switch deactivateResult {
        case .success():
            break
        case .failure(let error):
            print("[AudioEngineManager] Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }
    
    /// Initializes the audio file for recording.
    private func initializeAudioFile() {
        let inputFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        audioFilename = audioFileManager.getDocumentsDirectory().appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
        do {
            if let audioFilename = audioFilename {
                audioFile = try AVAudioFile(forWriting: audioFilename, settings: inputFormat.settings)
                recordingStartTime = Date()
                print("[AudioEngineManager] Started recording to file: \(audioFilename)")
            }
        } catch {
            print("[AudioEngineManager] Failed to create audio file for recording: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Implementing Protocol Methods
    
    /// Starts recording audio by ensuring the audio engine is running.
    public func startRecording() {
        // Start the audio engine if it's not already running
        if !isEngineRunning {
            startEngine()
        }
    }
    
    /// Stops recording audio by stopping the audio engine.
    public func stopRecording() {
        // Stop the audio engine if it's running
        if isEngineRunning {
            stopEngine()
        }
    }
    
    // MARK: - Deinitialization
    
    deinit {
        if isEngineRunning {
            stopEngine()
        }
        print("[AudioEngineManager] Deinitialized and audio engine stopped if it was running.")
    }
}
