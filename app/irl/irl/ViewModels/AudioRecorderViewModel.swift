//
//  AudioRecorderViewModel.swift
//  irl
//
//  Created by Elijah Arbee on 8/30/24.
//

import SwiftUI
import Combine

class AudioRecorderViewModel: ObservableObject {
    // View model is an @ObservableObject, meaning the SwiftUI views observing it will update when these
    // @Published properties change. This is the core of state management in this view model.
    
    @Published private(set) var audioState: AudioState // Holds shared audio state across the app (singleton).
    @Published private(set) var speechAnalysisService: SpeechAnalysisService // Manages speech analysis service (singleton).
    @Published private(set) var recordings: [RecordingViewModel] = [] // Holds the list of recordings.
    @Published var currentRecording: RecordingViewModel? // Tracks the currently active recording.
    @Published var errorMessage: String? // Holds error messages that might be triggered during recording or playback.
    
    private var cancellables = Set<AnyCancellable>() // Used for managing Combine subscriptions.

    init() {
        // Initializing singletons for AudioState and SpeechAnalysisService ensures state persistence across app views.
        self.audioState = AudioState.shared
        self.speechAnalysisService = SpeechAnalysisService.shared

        // Set up bindings to automatically update the UI when audio state changes or errors occur.
        setupBindings()
    }

    private func setupBindings() {
        // Binding localRecordings from AudioState to update the list of RecordingViewModels.
        // This ensures that when recordings are fetched or changed, the view updates accordingly.
        audioState.$localRecordings
            .sink { [weak self] recordings in
                self?.updateRecordingViewModels(recordings)
            }
            .store(in: &cancellables)

        // Binding currentRecording from AudioState to update the current recording being played or recorded.
        audioState.$currentRecording
            .sink { [weak self] recording in
                if let recording = recording {
                    self?.currentRecording = self?.recordings.first { $0.recording.id == recording.id }
                } else {
                    self?.currentRecording = nil
                }
            }
            .store(in: &cancellables)

        // Listening to error messages from AudioState and updating the error message in the view model.
        audioState.$errorMessage
            .sink { [weak self] message in
                self?.errorMessage = message
            }
            .store(in: &cancellables)

        // Also listening to error messages from the SpeechAnalysisService for speech analysis-related issues.
        speechAnalysisService.$errorMessage
            .sink { [weak self] message in
                if let message = message {
                    self?.errorMessage = message
                }
            }
            .store(in: &cancellables)
    }

    // Converts recordings fetched from AudioState into RecordingViewModel instances,
    // which handle additional behavior like speech analysis.
    private func updateRecordingViewModels(_ recordings: [AudioRecording]) {
        self.recordings = recordings.map { recording in
            let viewModel = RecordingViewModel(recording: recording, speechAnalysisService: speechAnalysisService)
            viewModel.startAnalysis() // Starts speech analysis for each recording immediately after fetching.
            return viewModel
        }
    }
    
    // Fetches recordings from the AudioState singleton, which likely interacts with persistent storage.
    func fetchRecordings() {
        audioState.fetchRecordings()
    }

    // Updates local recordings by calling the equivalent function in AudioState.
    // This function ensures that any stored audio recordings are loaded and available in the UI.
    func updateLocalRecordings() {
        audioState.updateLocalRecordings()
    }

    // Toggles the recording state by interacting with the AudioState singleton.
    func toggleRecording() {
        audioState.toggleRecording()
    }

    // Toggles playback for the current recording.
    func togglePlayback() {
        audioState.togglePlayback()
    }

    // Deletes a recording and removes it from both the AudioState and local view model list.
    func deleteRecording(_ recording: RecordingViewModel) {
        audioState.deleteRecording(recording.recording) // Calls into AudioState to handle deletion.
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            recordings.remove(at: index) // Remove from local state after deletion in AudioState.
        }
    }

    // Computed properties that expose the current audio recording/playback states from AudioState.
    var isRecording: Bool {
        audioState.isRecording
    }

    var isPlaying: Bool {
        audioState.isPlaying
    }

    var isPlaybackAvailable: Bool {
        audioState.isPlaybackAvailable
    }

    // Returns the current recording progress as a percentage.
    var recordingProgress: Double {
        audioState.recordingProgress
    }

    // Formats the current recording time for display.
    var formattedRecordingTime: String {
        audioState.formattedRecordingTime
    }

    // Formats the file size of the recording, potentially useful for UI display.
    func formattedFileSize(bytes: Int64) -> String {
        audioState.formattedFileSize(bytes: bytes)
    }
}

// View model for individual recordings, also an @ObservableObject to update the UI when state changes.
class RecordingViewModel: ObservableObject, Identifiable {
    let id: UUID // Unique identifier for each recording.
    let recording: AudioRecording // Holds the actual AudioRecording data.
    @Published var speechProbability: Double? // Stores the result of the speech analysis for this recording.
    
    private let speechAnalysisService: SpeechAnalysisService // Reference to the shared SpeechAnalysisService.
    private var cancellable: AnyCancellable? // Manages the subscription to the speech analysis probabilities.

    init(recording: AudioRecording, speechAnalysisService: SpeechAnalysisService) {
        self.id = recording.id
        self.recording = recording
        self.speechAnalysisService = speechAnalysisService
    }

    // Starts analysis by subscribing to speech probability updates from the speech analysis service.
    func startAnalysis() {
        cancellable = speechAnalysisService.$analysisProbabilities
            .map { $0[self.recording.url] }
            .assign(to: \.speechProbability, on: self) // Updates speechProbability when analysis is complete.
    }
}