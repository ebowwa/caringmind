//
//  FrameworkState.swift
//  irlapp
//
//  Created by Elijah Arbee on 10/29/24.
// uses DeviceManager & AVAudioSessionManager
// needs LifecycleManager, AudioEngineManager, AFiles, socketmanager, NetworkManager, AConverter, LocationManager, TranscriptionManager, SoundMeasurementManager, AudioPlaybackManager
//

import Foundation
import Combine
import ReSwift

// MARK: - Custom Audio Session Types

/// Represents the audio session category in an abstracted form.
public enum AudioSessionCategory: String, Equatable {
    case ambient
    case soloAmbient
    case playback
    case record
    case playAndRecord
    case multiRoute
}

/// Represents the audio session mode in an abstracted form.
public enum AudioSessionMode: String, Equatable {
    case `default`
    case gameChat
    case measurement
    case moviePlayback
    case spokenAudio
}

/// Represents the audio session options using a custom OptionSet.
public struct AudioSessionOptions: OptionSet, Equatable {
    public let rawValue: Int

    /// Public initializer required by OptionSet and RawRepresentable
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let allowBluetooth       = AudioSessionOptions(rawValue: 1 << 0)
    public static let allowBluetoothA2DP   = AudioSessionOptions(rawValue: 1 << 1)
    public static let defaultToSpeaker     = AudioSessionOptions(rawValue: 1 << 2)
    public static let mixWithOthers        = AudioSessionOptions(rawValue: 1 << 3)
}

// MARK: - App State

public struct AppState: StateType {
    // Device States
    public var devices: [DeviceState] = []
    
    // Audio Session State
    public var audioSession: AudioSessionState = AudioSessionState(
        category: .playAndRecord,
        mode: .default,
        options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker, .mixWithOthers],
        isActive: false
    )
    
    // Recording State
    public var isRecording: Bool = false
    public var recordingTime: TimeInterval = 0
    public var recordingProgress: Double = 0
    
    // Speech Recognition State
    public var transcription: String = ""
    public var isSpeaking: Bool = false
    
    // Audio Files State
    public var audioRecordings: [AudioRecording] = []
    
    // Error State
    public var errorMessage: String? = nil

    public init() {}
}

// MARK: - Device State Structure

public struct DeviceState: Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var isConnected: Bool
    public var isRecording: Bool

    public init(id: UUID, name: String, isConnected: Bool, isRecording: Bool) {
        self.id = id
        self.name = name
        self.isConnected = isConnected
        self.isRecording = isRecording
    }
}

// MARK: - Audio Session State Structure

public struct AudioSessionState: Equatable {
    public var category: AudioSessionCategory
    public var mode: AudioSessionMode
    public var options: AudioSessionOptions
    public var isActive: Bool

    public init(category: AudioSessionCategory, mode: AudioSessionMode, options: AudioSessionOptions, isActive: Bool) {
        self.category = category
        self.mode = mode
        self.options = options
        self.isActive = isActive
    }
}

// MARK: - Audio Files Actions

public struct AddRecordingAction: Action {
    public let recording: AudioRecording

    public init(recording: AudioRecording) {
        self.recording = recording
    }
}

public struct RemoveRecordingAction: Action {
    public let recordingID: UUID

    public init(recordingID: UUID) {
        self.recordingID = recordingID
    }
}

public struct UpdateRecordingAction: Action {
    public let recording: AudioRecording

    public init(recording: AudioRecording) {
        self.recording = recording
    }
}

public struct SetRecordingsAction: Action {
    public let recordings: [AudioRecording]

    public init(recordings: [AudioRecording]) {
        self.recordings = recordings
    }
}

// MARK: - Device Actions

public struct ConnectDeviceAction: Action {
    public let deviceID: UUID

    public init(deviceID: UUID) {
        self.deviceID = deviceID
    }
}

public struct DisconnectDeviceAction: Action {
    public let deviceID: UUID

    public init(deviceID: UUID) {
        self.deviceID = deviceID
    }
}

public struct StartRecordingAction: Action {
    public let deviceID: UUID

    public init(deviceID: UUID) {
        self.deviceID = deviceID
    }
}

public struct StopRecordingAction: Action {
    public let deviceID: UUID

    public init(deviceID: UUID) {
        self.deviceID = deviceID
    }
}

public struct AddDeviceAction: Action {
    public let device: DeviceState

    public init(device: DeviceState) {
        self.device = device
    }
}

// MARK: - Audio Session Actions

public struct ConfigureAudioSessionAction: Action {
    public let category: AudioSessionCategory
    public let mode: AudioSessionMode
    public let options: AudioSessionOptions

    public init(category: AudioSessionCategory, mode: AudioSessionMode, options: AudioSessionOptions) {
        self.category = category
        self.mode = mode
        self.options = options
    }
}

public struct DeactivateAudioSessionAction: Action {
    public init() {}
}

public struct AudioSessionInterruptedAction: Action {
    public init() {}
}

public struct AudioSessionResumedAction: Action {
    public init() {}
}

// MARK: - Recording Actions

/// Represents errors that occur during recording.
public struct RecordingErrorAction: Action {
    public let error: String

    public init(error: String) {
        self.error = error
    }
}

public struct StartSpecificTaskRecordingAction: Action {
    public let taskName: String

    public init(taskName: String) {
        self.taskName = taskName
    }
}

public struct StopSpecificTaskRecordingAction: Action {
    public let taskName: String

    public init(taskName: String) {
        self.taskName = taskName
    }
}

// MARK: - Speech Recognition Actions

public struct UpdateTranscriptionAction: Action {
    public let transcription: String

    public init(transcription: String) {
        self.transcription = transcription
    }
}

public struct UpdateSpeakingStatusAction: Action {
    public let isSpeaking: Bool

    public init(isSpeaking: Bool) {
        self.isSpeaking = isSpeaking
    }
}

// MARK: - Recording Time and Progress Actions

public struct UpdateRecordingTimeAction: Action {
    public let time: TimeInterval

    public init(time: TimeInterval) {
        self.time = time
    }
}

public struct UpdateRecordingProgressAction: Action {
    public let progress: Double

    public init(progress: Double) {
        self.progress = progress
    }
}

// MARK: - Error Actions

public struct ClearErrorAction: Action {
    public init() {}
}

// MARK: - Reducers

/// Handles device-related actions.
public func deviceReducer(action: Action, state: [DeviceState]?) -> [DeviceState] {
    var state = state ?? []

    switch action {
    case let connect as ConnectDeviceAction:
        if let index = state.firstIndex(where: { $0.id == connect.deviceID }) {
            state[index].isConnected = true
        }

    case let disconnect as DisconnectDeviceAction:
        if let index = state.firstIndex(where: { $0.id == disconnect.deviceID }) {
            state[index].isConnected = false
            state[index].isRecording = false
        }

    case let startRecording as StartRecordingAction:
        if let index = state.firstIndex(where: { $0.id == startRecording.deviceID }) {
            state[index].isRecording = true
        }

    case let stopRecording as StopRecordingAction:
        if let index = state.firstIndex(where: { $0.id == stopRecording.deviceID }) {
            state[index].isRecording = false
        }

    case let addDevice as AddDeviceAction:
        state.append(addDevice.device)

    default:
        break
    }

    return state
}

/// Handles audio session-related actions.
public func audioSessionReducer(action: Action, state: AudioSessionState?) -> AudioSessionState {
    var state = state ?? AudioSessionState(
        category: .playAndRecord,
        mode: .default,
        options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker, .mixWithOthers],
        isActive: false
    )

    switch action {
    case let configure as ConfigureAudioSessionAction:
        state.category = configure.category
        state.mode = configure.mode
        state.options = configure.options
        state.isActive = true

    case _ as DeactivateAudioSessionAction:
        state.isActive = false

    case _ as AudioSessionInterruptedAction:
        state.isActive = false

    case _ as AudioSessionResumedAction:
        state.isActive = true

    default:
        break
    }

    return state
}

/// Handles recording-related actions.
public func recordingReducer(action: Action, state: AppState?) -> AppState {
    var state = state ?? AppState()

    switch action {
    case let start as StartRecordingAction:
        state.isRecording = true
        state.errorMessage = nil

    case let stop as StopRecordingAction:
        state.isRecording = false
        state.errorMessage = nil

    case let error as RecordingErrorAction:
        state.errorMessage = error.error

    case let updateTranscription as UpdateTranscriptionAction:
        state.transcription = updateTranscription.transcription

    case let updateSpeaking as UpdateSpeakingStatusAction:
        state.isSpeaking = updateSpeaking.isSpeaking

    case let updateTime as UpdateRecordingTimeAction:
        state.recordingTime = updateTime.time

    case let updateProgress as UpdateRecordingProgressAction:
        state.recordingProgress = updateProgress.progress

    case _ as ClearErrorAction:
        state.errorMessage = nil

    default:
        break
    }

    return state
}

/// Handles audio files-related actions.
public func audioFilesReducer(action: Action, state: [AudioRecording]?) -> [AudioRecording] {
    var state = state ?? []

    switch action {
    case let add as AddRecordingAction:
        state.append(add.recording)

    case let remove as RemoveRecordingAction:
        state.removeAll { $0.id == remove.recordingID }

    case let update as UpdateRecordingAction:
        if let index = state.firstIndex(where: { $0.id == update.recording.id }) {
            state[index] = update.recording
        }

    case let set as SetRecordingsAction:
        state = set.recordings

    default:
        break
    }

    return state
}

/// Combines all reducers.
public func appReducer(action: Action, state: AppState?) -> AppState {
    var state = state ?? AppState()

    state.devices = deviceReducer(action: action, state: state.devices)
    state.audioSession = audioSessionReducer(action: action, state: state.audioSession)
    state = recordingReducer(action: action, state: state)
    state.audioRecordings = audioFilesReducer(action: action, state: state.audioRecordings)

    return state
}

// MARK: - Store

/// Initializes the ReSwift store with the combined reducer and initial state.
public let store = Store<AppState>(reducer: appReducer, state: nil)
