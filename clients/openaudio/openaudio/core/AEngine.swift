//
//  AEngine.swift
//  openaudiostandard
//
//  Created by Elijah Arbee on 10/23/24.
//

import Foundation
import Combine
import AVFoundation

// MARK: - AudioEngineManager

public class AudioEngineManager: NSObject, AudioEngineManagerProtocol {
    public static let shared = AudioEngineManager()
    
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
    
    private let audioEngine = AVAudioEngine()
    
    private weak var webSocketManager: WebSocketManagerProtocol?
    
    private let audioBufferSize: AVAudioFrameCount = 1024
    
    private var isRecording: Bool = false
    private var audioFile: AVAudioFile?
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
        // Removed setupAudioSession as AudioState handles it
    }
    
    /// Assigns the WebSocket manager for live streaming.
    /// - Parameter manager: An instance conforming to WebSocketManagerProtocol.
    public func assignWebSocketManager(manager: WebSocketManagerProtocol) {
        self.webSocketManager = manager
    }
    
    /// Starts the audio engine for live streaming and real-time processing.
    public func startEngine() {
        if isEngineRunning {
            print("[AudioEngineManager] Audio engine is already running.")
            return
        }
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: audioBufferSize, format: inputFormat) { [weak self] (buffer, time) in
            self?.processAudioBuffer(buffer: buffer, time: time)
        }
        
        do {
            try audioEngine.start()
            isEngineRunning = true
            print("[AudioEngineManager] Audio engine started.")
        } catch {
            print("[AudioEngineManager] Failed to start audio engine: \(error.localizedDescription)")
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
        print("[AudioEngineManager] Audio engine stopped.")
    }
    
    /// Starts recording audio to a file.
    public func startRecording() {
        guard !isRecording else {
            print("[AudioEngineManager] Already recording.")
            return
        }
        
        let audioFilename = AudioFileManager.shared.getDocumentsDirectory().appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
        
        let inputFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        do {
            audioFile = try AVAudioFile(forWriting: audioFilename, settings: inputFormat.settings)
            isRecording = true
            print("[AudioEngineManager] Started recording to file: \(audioFilename)")
        } catch {
            print("[AudioEngineManager] Failed to create audio file for recording: \(error.localizedDescription)")
        }
    }
    
    /// Stops recording audio to a file.
    public func stopRecording() {
        guard isRecording else {
            print("[AudioEngineManager] Not currently recording.")
            return
        }
        
        isRecording = false
        audioFile = nil
        print("[AudioEngineManager] Stopped recording.")
    }
    
    /// Processes the captured audio buffer, sends it via WebSocket, and publishes audio levels.
    /// - Parameters:
    ///   - buffer: The captured audio buffer.
    ///   - time: The time at which the buffer was captured.
    private func processAudioBuffer(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard let channelData = buffer.floatChannelData else { return }
        let frames = buffer.frameLength

        // Create Data from the entire buffer
        let data = Data(bytes: channelData[0], count: Int(frames) * MemoryLayout<Float>.size)
        
        // Send audio data via WebSocket
        webSocketManager?.sendAudioData(data)
        
        // Publish the audio buffer for speech recognition
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
        
        // If recording is active, write buffer to file
        if isRecording, let audioFile = audioFile {
            do {
                try audioFile.write(from: buffer)
            } catch {
                print("[AudioEngineManager] Failed to write buffer to file: \(error.localizedDescription)")
            }
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
}
