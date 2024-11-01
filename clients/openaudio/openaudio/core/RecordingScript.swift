//
//  RecordingScript.swift
//  openaudiostandard
//  TODO: will need to refractor/modify to allow multiple devices to use this i.e. the friend - entirely possible but needs work to dynamically configure `recording settings`
// TODO: the recording seems to pause at times if the speech was determined transcribed but time has elapsed and speech has paused
//  Created by Elijah Arbee on 10/23/24.
//

import Foundation
import AVFoundation
import Combine
import Speech

// MARK: - RecordingScript Class

public class RecordingScript: NSObject, RecordingManagerProtocol {
    // Singleton instance
    public static let shared = RecordingScript()

    // MARK: - Publishers
    @Published private(set) public var isRecordingState: Bool = false
    @Published private(set) public var recordingTimeValue: TimeInterval = 0
    @Published private(set) public var recordingProgressValue: Double = 0
    @Published private(set) public var errorMessageValue: String?

    // New Publishers for Speech Recognition
    @Published private(set) public var isSpeaking: Bool = false
    @Published private(set) public var transcription: String = ""

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

    // New Publishers for Speech
    public var isSpeakingPublisher: AnyPublisher<Bool, Never> {
        $isSpeaking.eraseToAnyPublisher()
    }

    public var transcriptionPublisher: AnyPublisher<String, Never> {
        $transcription.eraseToAnyPublisher()
    }

    // MARK: - Properties
    private let audioEngineManager = AudioEngineManager.shared
    private var audioLevelSubscription: AnyCancellable?
    private var audioBufferSubscription: AnyCancellable?
    private var recordingTimer: Timer?
    fileprivate var audioRecorder: AVAudioRecorder? // Changed to 'fileprivate' for extension access

    // Speech Recognition Properties
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) // Specify locale as needed
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // MARK: - Initialization
    private override init() { // Made private for singleton
        super.init()
        // Subscribe to the audio level updates
        audioLevelSubscription = audioEngineManager.audioLevelPublisher
            .sink { [weak self] audioLevel in
                print("Audio Level: \(audioLevel) dB")
                self?.recordingProgressValue = Double(audioLevel)
            }

        // Subscribe to audio buffer updates
        audioBufferSubscription = audioEngineManager.audioBufferPublisher
            .sink { buffer in
                print("Audio buffer received with frame length: \(buffer.frameLength)")
            }

        // Initialize the engine and prepare for recording
        setupAudioSession()
        audioEngineManager.startEngine()

        // Request Speech Recognition Authorization
        requestSpeechAuthorization()
    }

    // MARK: - Speech Recognition Authorization
    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("Speech recognition authorized.")
                case .denied, .restricted, .notDetermined:
                    print("Speech recognition not authorized.")
                    self?.errorMessageValue = "Speech recognition not authorized."
                @unknown default:
                    print("Unknown speech recognition authorization status.")
                    self?.errorMessageValue = "Unknown speech recognition authorization status."
                }
            }
        }
    }

    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true)
            print("Audio session is set up successfully.")
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
            self.errorMessageValue = "Failed to set up audio session: \(error.localizedDescription)"
        }
    }

    // MARK: - Recording Controls
    public func startRecording() { // Implementing the protocol method without 'manual' parameter
        print("Starting recording...")
        guard !isRecordingState else {
            print("Already recording.")
            return
        }

        // Define the recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000, // 16 kHz is recommended for speech recognition
            AVNumberOfChannelsKey: 1, // Mono channel is sufficient for speech
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        // Define the file URL for recording
        let audioFilename = AudioFileManager.shared.getDocumentsDirectory().appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")

        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            isRecordingState = true
            recordingTimeValue = 0
            recordingProgressValue = 0
            startRecordingTimer()

            // Start Speech Recognition
            startSpeechRecognition()
        } catch {
            print("Could not start recording: \(error.localizedDescription)")
            self.errorMessageValue = "Could not start recording: \(error.localizedDescription)"
        }
    }

    public func stopRecording() {
        print("Stopping recording...")
        guard isRecordingState else {
            print("Not currently recording.")
            return
        }

        audioRecorder?.stop()
        audioRecorder = nil
        isRecordingState = false
        stopRecordingTimer()

        // Stop Speech Recognition
        stopSpeechRecognition()
    }

    // MARK: - Recording Timer
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecordingState else { return }
            self.recordingTimeValue += 1.0
            self.updateAudioLevels()
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    private func updateAudioLevels() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        let progress = mapAudioLevelToProgress(averagePower)
        recordingProgressValue = progress
    }

    private func mapAudioLevelToProgress(_ averagePower: Float) -> Double {
        // Example mapping from decibels (-160 dB to 0 dB) to progress (0.0 to 1.0)
        let minDb: Float = -160
        let maxDb: Float = 0
        let normalized = (averagePower - minDb) / (maxDb - minDb)
        return Double(max(0, min(1, normalized)))
    }
    
    // MARK: - Speech Recognition Methods
    private func startSpeechRecognition() {
        // Ensure previous task is canceled
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        // Initialize the recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create a SFSpeechAudioBufferRecognitionRequest object")
            self.errorMessageValue = "Unable to create a speech recognition request."
            return
        }

        recognitionRequest.shouldReportPartialResults = true

        // Configure the audio session for speech recognition
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session properties weren't set because of an error: \(error.localizedDescription)")
            self.errorMessageValue = "Audio session error: \(error.localizedDescription)"
            return
        }

        // Start the recognition task
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech recognizer is not available.")
            self.errorMessageValue = "Speech recognizer is not available."
            return
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                // Update transcription
                self.transcription = result.bestTranscription.formattedString
                // Update isSpeaking based on result
                self.isSpeaking = !result.isFinal
                print("Transcription: \(self.transcription)")
            }

            if let error = error {
                print("Speech recognition error: \(error.localizedDescription)")
                self.errorMessageValue = "Speech recognition error: \(error.localizedDescription)"
                self.isSpeaking = false
                self.recognitionTask = nil
            }

            if result?.isFinal == true {
                self.isSpeaking = false
                self.recognitionTask = nil
            }
        }

        // Attach the audio input to the recognition request
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        // Start the audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error: \(error.localizedDescription)")
            self.errorMessageValue = "Audio engine error: \(error.localizedDescription)"
        }
    }

    private func stopSpeechRecognition() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        isSpeaking = false
    }

    // MARK: - Deinitialization
    deinit {
        audioLevelSubscription?.cancel()
        audioBufferSubscription?.cancel()
        audioEngineManager.stopEngine()
        stopSpeechRecognition()
        print("Recording script cleanup completed.")
    }
}

// MARK: - AVAudioRecorderDelegate
extension RecordingScript: AVAudioRecorderDelegate {
    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessageValue = "Recording did not finish successfully."
                self?.isRecordingState = false
            }
        }
    }

    public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessageValue = "Recording encoding error: \(error.localizedDescription)"
                self?.isRecordingState = false
            }
        }
    }
}

// MARK: - Extension to Expose Recording URL and Transcription
extension RecordingScript {
    public func currentRecordingURL() -> URL? {
        return audioRecorder?.url
    }

    public func currentTranscription() -> String {
        return transcription
    }

    // Property to indicate if the transcription is final
    public var isFinalTranscription: Bool {
        return !isSpeaking
    }
}
