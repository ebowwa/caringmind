//
//  AudioState.swift
//  openaudiostandard
//
//  Created by Elijah Arbee on 10/23/24.
//
import UIKit
import Foundation
import AVFoundation
import Combine

// MARK: - AudioState Class

public class AudioState: NSObject, AudioStateProtocol {
    
    // Singleton instance to ensure one central state for audio management.
    public static let shared = AudioState()
    
    // MARK: - Published Properties
    
    @Published public var isRecording: Bool = false
    @Published public var isPlaying: Bool = false
    @Published public var recordingTime: TimeInterval = 0
    @Published public var recordingProgress: Double = 0
    @Published public var isPlaybackAvailable: Bool = false
    @Published public var errorMessage: String?
    @Published public var localRecordings: [AudioRecording] = []
    @Published public var currentRecording: AudioRecording?
    
    // MARK: - Persistent Storage Properties
    
    private let userDefaults = UserDefaults.standard
    private let isRecordingEnabledKey = "isRecordingEnabled"
    private let isBackgroundRecordingEnabledKey = "isBackgroundRecordingEnabled"
    
    public var isRecordingEnabled: Bool {
        get { userDefaults.bool(forKey: isRecordingEnabledKey) }
        set { userDefaults.set(newValue, forKey: isRecordingEnabledKey) }
    }
    
    public var isBackgroundRecordingEnabled: Bool {
        get { userDefaults.bool(forKey: isBackgroundRecordingEnabledKey) }
        set { userDefaults.set(newValue, forKey: isBackgroundRecordingEnabledKey) }
    }
    
    // MARK: - Managers
    
    private let soundMeasurementManager = SoundMeasurementManager.shared
    private let recordingManager: RecordingManagerProtocol
    private let playbackManager: AudioPlaybackManager = AudioPlaybackManager()
    
    // MARK: - WebSocket Manager
    
    public var webSocketManager: WebSocketManagerProtocol?

    // MARK: - Recording Control Flags
    
    private var isManualRecording: Bool = false // Indicates if the current recording was started manually.
    
    // MARK: - Publishers
    
    private var cancellables: Set<AnyCancellable> = []
    
    // MARK: - Recording Properties
    private var recordingTimer: Timer?
    
    // MARK: - Initialization

    public override init() { // Changed to 'public' to align with class access level
        self.recordingManager = RecordingScript.shared // Updated to use singleton instance
        super.init()
        
        setupAudioSession(caller: "AudioState.init")
        setupNotifications()
        setupBindings()
        updateLocalRecordings()
        
        if isBackgroundRecordingEnabled {
            startRecording(manual: false)
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupBindings() {
        // Bind SoundMeasurementManager's audio level to recordingProgress
        soundMeasurementManager.$currentAudioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.recordingProgress = level
            }
            .store(in: &cancellables)
        
        // Bind RecordingManager's published properties to AudioState's properties
        recordingManager.isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                self?.isRecording = isRecording
            }
            .store(in: &cancellables)
        
        recordingManager.recordingTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                self?.recordingTime = time
            }
            .store(in: &cancellables)
        
        recordingManager.recordingProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.recordingProgress = progress
            }
            .store(in: &cancellables)
        
        recordingManager.errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.errorMessage = error
            }
            .store(in: &cancellables)
        
        // Bind PlaybackManager's isPlaying to AudioState's isPlaying
        playbackManager.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                self?.isPlaying = isPlaying
            }
            .store(in: &cancellables)
        
        // Bind PlaybackManager's errorMessage to AudioState's errorMessage
        playbackManager.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                if let error = error {
                    self?.errorMessage = error
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppBackgrounding), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppTermination), name: UIApplication.willTerminateNotification, object: nil)
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handleAppBackgrounding() {
        if isBackgroundRecordingEnabled {
            setupAudioSession(caller: "handleAppBackgrounding")
            if !AudioEngineManager.shared.isEngineRunning {
                AudioEngineManager.shared.startEngine()
            }
        } else {
            stopRecording()
        }
    }
    
    @objc private func handleAppTermination() {
        if isRecording {
            stopRecording()
        }
    }
    
    // MARK: - WebSocket Setup
    
    public func setupWebSocket(manager: WebSocketManagerProtocol) {
        self.webSocketManager = manager
        AudioEngineManager.shared.assignWebSocketManager(manager: manager)
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession(caller: String = #function) {
        let device = UIDevice.current
        let deviceInfo = "Device: \(device.model), OS: \(device.systemName) \(device.systemVersion)"
        print("[DeviceInfo] Called by \(caller) - \(deviceInfo)")
        
        // Delegate audio session setup to RecordingManager if needed
        // Uncomment if RecordingManager handles audio session
        // recordingManager.setupAudioSession(caller: caller)
    }
    
    // MARK: - Recording Controls
    
    public func toggleRecording(manual: Bool) {
        if isRecording {
            stopRecording()
        } else {
            startRecording(manual: manual)
        }
    }
    
    public func startRecording(manual: Bool) {
        if isRecording { return }
        
        isManualRecording = manual
        
        if webSocketManager != nil {
            AudioEngineManager.shared.startEngine()
            recordingManager.startRecording()
        } else {
            recordingManager.startRecording()
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = true
            self?.recordingTime = 0
            self?.recordingProgress = 0
            self?.errorMessage = nil
        }
    }
    
    public func stopRecording() {
        if !isRecording { return }
        
        if webSocketManager != nil {
            AudioEngineManager.shared.stopEngine()
        }
        
        recordingManager.stopRecording()
        
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
            self?.updateCurrentRecording()
            self?.updateLocalRecordings()
            self?.isPlaybackAvailable = true
            self?.isManualRecording = false
        }
    }
    
    // MARK: - Playback Controls
    
    public func togglePlayback() {
        if isPlaying {
            playbackManager.pausePlayback()
        } else if let recordingURL = currentRecording?.url {
            playbackManager.startPlayback(for: recordingURL)
        } else {
            errorMessage = "No recording available to play."
        }
    }
    
    // MARK: - File Management
    
    private func updateCurrentRecording() {
        guard let url = recordingManager.currentRecordingURL() else { return }
        let recordings = AudioFileManager.shared.updateLocalRecordings()
        currentRecording = recordings.first { $0.url == url }
    }
    
    public func updateLocalRecordings() {
        let updatedRecordings = AudioFileManager.shared.updateLocalRecordings()
        
        DispatchQueue.main.async { [weak self] in
            self?.localRecordings = updatedRecordings
        }
    }
    
    public func fetchRecordings() {
        updateLocalRecordings()
    }
    
    public func deleteRecording(_ recording: AudioRecording) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            do {
                try AudioFileManager.shared.deleteRecording(recording)
                DispatchQueue.main.async {
                    self?.updateLocalRecordings()
                    if self?.currentRecording?.url == recording.url {
                        self?.currentRecording = nil
                        self?.isPlaybackAvailable = false
                    }
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = "Error deleting recording: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Formatting Helpers
    
    public var formattedRecordingTime: String {
        AudioFileManager.shared.formattedDuration(recordingTime)
    }
    
    public func formattedFileSize(bytes: Int64) -> String {
        AudioFileManager.shared.formattedFileSize(bytes: bytes)
    }
    
    // MARK: - AudioLevelPublisher
    
    public var audioLevelPublisher: AnyPublisher<Float, Never> {
        soundMeasurementManager.$currentAudioLevel
            .map { Float($0) }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Utility
    
    public func currentRecordingURL() -> URL? {
        return recordingManager.currentRecordingURL()
    }
}


// MARK: - AVAudioRecorderDelegate

extension AudioState: AVAudioRecorderDelegate {
    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Recording did not finish successfully."
                self?.isRecording = false
            }
        }
    }

    public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Recording encoding error: \(error.localizedDescription)"
                self?.isRecording = false
            }
        }
    }
}

