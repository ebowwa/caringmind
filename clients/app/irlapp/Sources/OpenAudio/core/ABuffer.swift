// AudioBufferProcessor.swift
// openaudiostandard
//
// Created by Elijah Arbee on 10/30/24.
// Enhanced with VAD - Voice Activity Detection

import Foundation
import Combine
import AVFoundation

/// A protocol defining the interface for processing audio buffers.
public protocol AudioBufferProcessorProtocol: AnyObject {
    /// Publisher that emits the current audio level (normalized between 0.0 and 1.0).
    var audioLevelPublisher: AnyPublisher<Float, Never> { get }
    
    /// Publisher that emits audio buffers for processing (e.g., speech recognition).
    var audioBufferPublisher: AnyPublisher<AVAudioPCMBuffer, Never> { get }
    
    /// Assigns a WebSocket manager for live audio streaming.
    /// - Parameter manager: An object conforming to `WebSocketManagerProtocol`.
    func assignWebSocketManager(manager: WebSocketManagerProtocol)
    
    /// Assigns a Voice Activity Detector.
    /// - Parameter vad: An object conforming to `VoiceActivityDetectorProtocol`.
    func assignVoiceActivityDetector(vad: VoiceActivityDetectorProtocol)
    
    /// Processes the captured audio buffer.
    /// - Parameters:
    ///   - buffer: The captured audio buffer.
    ///   - time: The time at which the buffer was captured.
    func processAudioBuffer(buffer: AVAudioPCMBuffer, time: AVAudioTime)
}

public class AudioBufferProcessor: AudioBufferProcessorProtocol {
    
    // MARK: - Subjects
    
    private let audioLevelSubject = PassthroughSubject<Float, Never>()
    public var audioLevelPublisher: AnyPublisher<Float, Never> {
        audioLevelSubject.eraseToAnyPublisher()
    }
    
    private let audioBufferSubject = PassthroughSubject<AVAudioPCMBuffer, Never>()
    public var audioBufferPublisher: AnyPublisher<AVAudioPCMBuffer, Never> {
        audioBufferSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Dependencies
    
    private weak var webSocketManager: WebSocketManagerProtocol?
    private var voiceActivityDetector: VoiceActivityDetectorProtocol?
    
    // Combine
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initializes the AudioBufferProcessor.
    public init() {
        // Initialization without audioFileManager since it's removed
    }
    
    // MARK: - Public Methods
    
    /// Assigns the WebSocket manager for live streaming.
    /// - Parameter manager: An instance conforming to `WebSocketManagerProtocol`.
    public func assignWebSocketManager(manager: WebSocketManagerProtocol) {
        self.webSocketManager = manager
    }
    
    /// Assigns a Voice Activity Detector.
    /// - Parameter vad: An object conforming to `VoiceActivityDetectorProtocol`.
    public func assignVoiceActivityDetector(vad: VoiceActivityDetectorProtocol) {
        self.voiceActivityDetector = vad
    }
    
    /// Processes the captured audio buffer, sends it via WebSocket, and publishes audio levels.
    /// Includes Voice Activity Detection to filter out non-speech buffers.
    /// - Parameters:
    ///   - buffer: The captured audio buffer.
    ///   - time: The time at which the buffer was captured.
    public func processAudioBuffer(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Perform Voice Activity Detection
        guard let vad = voiceActivityDetector, vad.isSpeech(buffer: buffer) else {
            // Buffer does not contain speech; skip processing
            return
        }
        
        guard let channelData = buffer.floatChannelData else { return }
        let frames = buffer.frameLength

        // Create Data from the entire buffer
        let data = Data(bytes: channelData[0], count: Int(frames) * MemoryLayout<Float>.size)
        
        // Send audio data via WebSocket
        webSocketManager?.sendAudioData(data)
        
        // Publish the audio buffer for speech recognition or other processing
        audioBufferSubject.send(buffer)
        
        // Calculate average power for audio level
        let rms = calculateRMS(channelData: channelData[0], frameCount: Int(frames))
        
        // Convert RMS to average power in decibels
        let avgPower = 20 * log10(rms)
        
        // Handle cases where rms might be zero to avoid -infinity
        let normalizedPower = rms > 0 ? avgPower : -100.0 // Arbitrary low value
        
        // Publish the audio level
        DispatchQueue.main.async { [weak self] in
            self?.audioLevelSubject.send(normalizedPower)
        }
    }
    
    /// Calculates the Root Mean Square (RMS) of the audio signal.
    /// - Parameters:
    ///   - channelData: Pointer to the audio samples.
    ///   - frameCount: Number of frames in the buffer.
    /// - Returns: The RMS value.
    private func calculateRMS(channelData: UnsafeMutablePointer<Float>, frameCount: Int) -> Float {
        // Step 1: Extract the relevant samples
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        
        // Step 2: Calculate the sum of squares
        let sumOfSquares = samples.reduce(0) { $0 + ($1 * $1) }
        
        // Step 3: Calculate the mean of the squares
        let meanSquare = sumOfSquares / Float(frameCount)
        
        // Step 4: Calculate the root mean square (RMS)
        let rms = sqrt(meanSquare)
        
        return rms
    }
    
    deinit {
        print("[AudioBufferProcessor] Deinitialized.")
    }
}
