//
//  OpenAudioManager.swift
//  openaudio
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

    // Initializer
    private override init() {
        self.audioState = AudioState.shared
        self.audioEngineManager = AudioEngineManager.shared
        self.soundMeasurementManager = SoundMeasurementManager.shared
        self.audioPlaybackManager = AudioPlaybackManager()
        self.locationManager = LocationManager.shared
        self.deviceManager = DeviceManager.shared
        super.init()
    }

    // Public methods to interact with the SDK
    public func startRecording(manual: Bool = false) {
        audioState.startRecording(manual: manual)
    }

    public func stopRecording() {
        audioState.stopRecording()
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
