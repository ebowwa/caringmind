// RecordingScript.swift
// openaudiostandard
//
// Created by Elijah Arbee on 10/23/24.

import Foundation
import Combine
import AVFoundation
import Speech
import ReSwift

// MARK: - RecordingManagerProtocol

/// A protocol defining the interface for managing audio recordings.
public protocol RecordingManagerProtocol: AnyObject {
    var isRecording: AnyPublisher<Bool, Never> { get }
    var recordingTime: AnyPublisher<TimeInterval, Never> { get }
    var recordingProgress: AnyPublisher<Double, Never> { get }
    var errorMessage: AnyPublisher<String?, Never> { get }
    var transcriptionPublisher: AnyPublisher<String, Never> { get }
    var isFinalTranscription: Bool { get }
    
    func startRecording()
    func stopRecording()
    func currentRecordingURL() -> URL?
}

// MARK: - RecordingScript

public class RecordingScript: NSObject, RecordingManagerProtocol, StoreSubscriber {
    // MARK: - Publishers
    @Published private(set) public var isRecordingState: Bool = false
    @Published private(set) public var recordingTimeValue: TimeInterval = 0
    @Published private(set) public var recordingProgressValue: Double = 0
    @Published private(set) public var errorMessageValue: String?
    
    // MARK: - Speech Recognition Publishers
    @Published private(set) public var isSpeaking: Bool = false
    @Published private(set) public var transcription: String = ""
    
    // Use a PassthroughSubject for transcription updates if needed elsewhere
    public let transcriptionSubject = PassthroughSubject<String, Never>()
    
    // MARK: - Protocol Conformance
    public var isRecording: AnyPublisher<Bool, Never> {
        $isRecordingState.eraseToAnyPublisher()
    }

    public var recordingTime: AnyPublisher<TimeInterval, Never> {
        $recordingTimeValue.eraseToAnyPublisher()
    }

    public var recordingProgress: AnyPublisher<Double, Never> {
        $recordingProgressValue.eraseToAnyPublisher()
    }

    public var errorMessage: AnyPublisher<String?, Never> {
        $errorMessageValue.eraseToAnyPublisher()
    }

    public var transcriptionPublisher: AnyPublisher<String, Never> {
        $transcription.eraseToAnyPublisher()
    }
    
    public var isFinalTranscription: Bool {
        return !isSpeaking
    }
    
    // MARK: - Properties
    private let audioEngineManager: AudioEngineManagerProtocol
    private let audioSessionManager: AVAudioSessionManagerProtocol
    private let audioFileManager: AudioFileManagerProtocol
    private var cancellables: Set<AnyCancellable> = []
    private var recordingTimer: Timer?
    
    // Speech Recognition Properties
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // ReSwift Store for dispatching actions
    private let store: Store<AppState>?
    
    // MARK: - Initialization
    
    /// Initializes a new instance of RecordingScript with injected dependencies.
    /// - Parameters:
    ///   - audioEngineManager: Manages audio engine operations.
    ///   - audioSessionManager: Manages AVAudioSession configurations.
    ///   - audioFileManager: Manages audio file operations.
    ///   - store: ReSwift store for dispatching actions.
    ///   - speechRecognizer: Configured SFSpeechRecognizer. Defaults to "en-US" locale.
    public init(audioEngineManager: AudioEngineManagerProtocol,
                audioSessionManager: AVAudioSessionManagerProtocol,
                audioFileManager: AudioFileManagerProtocol,
                store: Store<AppState>,
                speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))) {
        self.audioEngineManager = audioEngineManager
        self.audioSessionManager = audioSessionManager
        self.audioFileManager = audioFileManager
        self.store = store
        self.speechRecognizer = speechRecognizer
        super.init()
        subscribeToAudioUpdates()
        requestSpeechAuthorization()
        subscribeToStoreChanges()
    }
    
    // MARK: - Setup Methods
    
    /// Subscribes to audio updates from the AudioEngineManager.
    private func subscribeToAudioUpdates() {
        audioEngineManager.audioLevelPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] audioLevel in
                self?.handleAudioLevel(audioLevel)
            }
            .store(in: &cancellables)

        audioEngineManager.audioBufferPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] buffer in
                self?.processAudioBufferForSpeechRecognition(buffer)
            }
            .store(in: &cancellables)
    }

    /// Subscribes to relevant changes in the ReSwift store.
    private func subscribeToStoreChanges() {
        store?.subscribe(self) { state in
            state.select { $0 }
        }
    }
    
    // MARK: - Speech Recognition Authorization
    
    /// Requests authorization for speech recognition.
    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("Speech recognition authorized.")
                case .denied, .restricted, .notDetermined:
                    print("Speech recognition not authorized.")
                    self?.errorMessageValue = "Speech recognition not authorized."
                    self?.store?.dispatch(RecordingErrorAction(error: "Speech recognition not authorized."))
                @unknown default:
                    print("Unknown speech recognition authorization status.")
                    self?.errorMessageValue = "Unknown speech recognition authorization status."
                    self?.store?.dispatch(RecordingErrorAction(error: "Unknown speech recognition authorization status."))
                }
            }
        }
    }


    // MARK: - Recording Controls
    
    /// Starts the audio recording by initiating speech recognition.
    public func startRecording() {
        print("Starting speech recognition...")
        guard !isRecordingState else {
            print("Already recording.")
            return
        }

        // Start Speech Recognition
        startSpeechRecognition()
        isRecordingState = true
        
        // Dispatch action to store that recording started
        if let deviceID = audioFileManager.currentDeviceID { // Access currentDeviceID from audioFileManager
            store?.dispatch(StartRecordingAction(deviceID: deviceID))
        }
    }
    
    /// Stops the audio recording by terminating speech recognition.
    public func stopRecording() {
        print("Stopping speech recognition...")
        guard isRecordingState else {
            print("Not currently recording.")
            return
        }

        // Stop Speech Recognition
        stopSpeechRecognition()
        isRecordingState = false
        
        // Dispatch action to store that recording stopped
        if let deviceID = audioFileManager.currentDeviceID { // Access currentDeviceID from audioFileManager
            store?.dispatch(StopRecordingAction(deviceID: deviceID))
        }
    }
    
    // MARK: - Recording Timer
    
    /// Starts the timer to update recording time and audio levels.
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecordingState else { return }
            self.recordingTimeValue += 1.0
            self.updateAudioLevels()
            
            // Dispatch recording time updates to the store
            self.store?.dispatch(UpdateRecordingTimeAction(time: self.recordingTimeValue))
        }
    }
    
    /// Stops the recording timer.
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    /// Updates the audio levels based on the AudioEngineManager's publisher.
    private func updateAudioLevels() {
        // Implementation can be expanded based on specific requirements
    }

    // MARK: - Speech Recognition Methods
    
    /// Starts the speech recognition process.
    private func startSpeechRecognition() {
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create a SFSpeechAudioBufferRecognitionRequest object")
            self.errorMessageValue = "Unable to create a speech recognition request."
            store?.dispatch(RecordingErrorAction(error: "Unable to create a speech recognition request."))
            return
        }

        recognitionRequest.shouldReportPartialResults = true

        startNewRecognitionTask()
    }

    /// Initiates a new speech recognition task.
    private func startNewRecognitionTask() {
        guard let recognitionRequest = recognitionRequest else {
            return
        }
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech recognizer is not available.")
            self.errorMessageValue = "Speech recognizer is not available."
            store?.dispatch(RecordingErrorAction(error: "Speech recognizer is not available."))
            return
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let transcriptionText = result.bestTranscription.formattedString
                self.transcription = transcriptionText
                self.isSpeaking = !result.isFinal
                print("Transcription: '\(transcriptionText)', isFinal: \(result.isFinal)")
                print("isSpeaking: \(self.isSpeaking)")

                self.transcriptionSubject.send(transcriptionText)
                
                // Dispatch transcription update
                self.store?.dispatch(UpdateTranscriptionAction(transcription: transcriptionText))
                self.store?.dispatch(UpdateSpeakingStatusAction(isSpeaking: self.isSpeaking))
            }

            if error != nil || result?.isFinal == true {
                print("Recognition task completed with error: \(String(describing: error?.localizedDescription))")
                self.isSpeaking = false
                self.store?.dispatch(UpdateSpeakingStatusAction(isSpeaking: self.isSpeaking))
                self.recognitionTask?.cancel()
                self.recognitionTask = nil

                if let error = error {
                    self.errorMessageValue = "Speech recognition error: \(error.localizedDescription)"
                    self.store?.dispatch(RecordingErrorAction(error: "Speech recognition error: \(error.localizedDescription)"))
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
                    self.recognitionRequest?.shouldReportPartialResults = true
                    self.startNewRecognitionTask()
                }
            }
        }
    }

    /// Stops the speech recognition process.
    private func stopSpeechRecognition() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isSpeaking = false
        print("Speech recognition stopped.")
        
        // Dispatch final speaking status
        store?.dispatch(UpdateSpeakingStatusAction(isSpeaking: self.isSpeaking))
    }

    // MARK: - Utility
    
    /// Retrieves the URL of the current recording.
    /// - Returns: The URL of the current recording if available.
    public func currentRecordingURL() -> URL? {
        return audioEngineManager.currentAudioFileURL
    }
    
    // MARK: - Deinitialization
    
    deinit {
        cancellables.forEach { $0.cancel() }
        audioEngineManager.stopEngine()
        stopSpeechRecognition()
        stopRecordingTimer()
        print("RecordingScript deinitialized and cleaned up.")
    }
    
    // MARK: - Handle Audio Level
    
    private func handleAudioLevel(_ audioLevel: Float) {
        print("Audio Level: \(audioLevel) dB")
        self.recordingProgressValue = Double(audioLevel)
        
        // Dispatch recording progress updates to the store
        self.store?.dispatch(UpdateRecordingProgressAction(progress: self.recordingProgressValue))
    }
    
    // MARK: - processAudioBufferForSpeechRecognition
    
    /// Appends the audio buffer to the speech recognition request.
    /// - Parameter buffer: The audio buffer to process.
    func processAudioBufferForSpeechRecognition(_ buffer: AVAudioPCMBuffer) {
        print("Appending audio buffer to recognition request.")
        recognitionRequest?.append(buffer)
    }

    
    // MARK: - StoreSubscriber Conformance
    
    public func newState(state: AppState) {
        // Handle state updates if necessary
    }
}
