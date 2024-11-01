# OpenAudio Framework Documentation

Welcome to the OpenAudio Framework documentation! This guide will help you integrate and utilize the OpenAudio framework within your iOS application. OpenAudio provides a comprehensive suite of tools for audio recording, playback, live streaming, transcription, device management, and more.

## Table of Contents

1. [Overview](#overview)
2. [Installation](#installation)
3. [Getting Started](#getting-started)
4. [Framework Components](#framework-components)
    - [OpenAudioManager](#openaudiomanager)
    - [AudioFileManager](#audiofilemanager)
    - [RecordingScript](#recordingscript)
    - [DeviceManager](#devicemanager)
    - [AudioEngineManager](#audioenginemanager)
    - [TranscriptionManager](#transcriptionmanager)
    - [SpeechRecognitionManager](#speechrecognitionmanager)
    - [WebSocketManager](#websocketmanager)
    - [AudioState](#audiostate)
    - [SoundMeasurementManager](#soundmeasurementmanager)
    - [LocationManager](#locationmanager)
    - [AudioConverter](#audioconverter)
    - [AudioPlaybackManager](#audioplaybackmanager)
5. [Integration Steps](#integration-steps)
6. [Usage Examples](#usage-examples)
    - [Starting and Stopping Recording](#starting-and-stopping-recording)
    - [Playback Control](#playback-control)
    - [Live Audio Streaming](#live-audio-streaming)
    - [Transcription Handling](#transcription-handling)
    - [Device Management](#device-management)
    - [Location Tracking](#location-tracking)
7. [API Reference](#api-reference)
8. [Best Practices](#best-practices)
9. [Troubleshooting](#troubleshooting)
10. [Support](#support)

---

## Overview

OpenAudio is a robust Swift framework designed to simplify audio-related functionalities in your iOS applications. It offers features such as:

- **Audio Recording**: Capture audio with customizable settings.
- **Audio Playback**: Play recorded or streamed audio.
- **Live Streaming**: Stream audio data via WebSockets.
- **Transcription**: Convert spoken words into text in real-time.
- **Device Management**: Manage multiple audio devices.
- **Location Tracking**: Integrate location data with audio recordings.
- **Sound Measurement**: Monitor and analyze audio levels.
- **File Management**: Handle audio file storage and conversion.

This documentation will guide you through setting up and leveraging these features effectively.

---

## Installation

### Prerequisites

- **Xcode**: Ensure you have Xcode installed (version 14.0 or later recommended).
- **Swift**: Compatible with Swift 5.5 or later.
- **iOS Deployment Target**: iOS 13.0 or higher.

### Adding OpenAudio to Your Project

1. **Clone the Repository**:

    ```bash
    git clone https://github.com/YourUsername/OpenAudio.git
    ```

2. **Add OpenAudio to Your Project**:

    - Drag and drop the `OpenAudio` folder into your Xcode project.
    - Ensure that the files are added to your target.

3. **Import OpenAudio in Your Swift Files**:

    ```swift
    import OpenAudio
    ```

*Alternatively*, if OpenAudio is available via Swift Package Manager (SPM), you can add it as a dependency:

1. **Open Your Project in Xcode**.
2. **Navigate to** `File` > `Add Packages...`.
3. **Enter the Repository URL** for OpenAudio.
4. **Select the Package** and **Add to Your Project**.

---

## Getting Started

To quickly get started with OpenAudio, follow these basic steps:

1. **Initialize the OpenAudioManager**.
2. **Configure WebSocket for Live Streaming** (optional).
3. **Start Recording**.
4. **Handle Transcriptions** (optional).
5. **Playback Recorded Audio**.

Refer to the [Usage Examples](#usage-examples) section for detailed implementations.

---

## Framework Components

OpenAudio is composed of several key components, each responsible for different functionalities. Understanding these components will help you effectively integrate and utilize the framework.

### OpenAudioManager

**File**: `OpenAudioManager.swift`

**Description**: The central manager coordinating various components of OpenAudio. It provides a unified interface to start/stop recording, playback, streaming, and manage transcriptions.

**Key Methods**:

- `startRecording(manual: Bool)`
- `stopRecording()`
- `togglePlayback()`
- `startStreaming()`
- `stopStreaming()`
- `setupWebSocket(url: URL)`

**Usage**:

```swift
let audioManager = OpenAudioManager.shared
audioManager.startRecording(manual: true)
```

### AudioFileManager

**File**: `AFiles.swift`

**Description**: Handles file-related operations such as fetching, deleting, formatting, and sending audio recordings and transcriptions.

**Key Methods**:

- `getDocumentsDirectory() -> URL`
- `updateLocalRecordings() -> [AudioRecording]`
- `deleteRecording(_ recording: AudioRecording) throws`
- `formattedDuration(_ duration: TimeInterval) -> String`
- `formattedFileSize(bytes: Int64) -> String`
- `saveTranscriptions(_ data: TranscriptionData)`
- `loadTranscriptions() -> TranscriptionData?`
- `sendTranscriptions(_ data: TranscriptionData, to url: URL, completion: @escaping (Result<Void, Error>) -> Void)`
- `sendZipOfTranscriptionsAndAudio(to url: URL, completion: @escaping (Result<Void, Error>) -> Void)`
- `sendAudioFiles(to url: URL, completion: @escaping (Result<Void, Error>) -> Void)`

**Usage**:

```swift
let fileManager = AudioFileManager.shared
let recordings = fileManager.updateLocalRecordings()
```

### RecordingScript

**File**: `RecordingScript.swift`

**Description**: Manages the audio recording process, including starting/stopping recordings, handling audio levels, and integrating speech recognition.

**Key Methods**:

- `startRecording()`
- `stopRecording()`
- `currentRecordingURL() -> URL?`
- `currentTranscription() -> String`
- `isFinalTranscription: Bool`

**Usage**:

```swift
let recordingScript = RecordingScript.shared
recordingScript.startRecording()
```

### DeviceManager

**File**: `ADeviceManager.swift`

**Description**: Manages multiple audio devices, allowing you to add, remove, connect, disconnect, and control recordings on each device.

**Key Classes**:

- `AudioDevice`: Represents an individual audio device.
- `DeviceManager`: Singleton to manage all connected devices.

**Key Methods**:

- `addDevice(_ device: Device)`
- `removeDevice(_ device: Device)`
- `startRecording(on device: Device)`
- `stopRecording(on device: Device)`
- `startRecordingOnAllDevices()`
- `stopRecordingOnAllDevices()`

**Usage**:

```swift
let deviceManager = DeviceManager.shared
let newDevice = AudioDevice(name: "Microphone 1")
deviceManager.addDevice(newDevice)
deviceManager.startRecording(on: newDevice)
```

### AudioEngineManager

**File**: `AEngine.swift`

**Description**: Manages the audio engine for live streaming and real-time processing. Handles audio buffer processing, streaming via WebSockets, and recording to files.

**Key Methods**:

- `assignWebSocketManager(manager: WebSocketManagerProtocol)`
- `startEngine()`
- `stopEngine()`
- `startRecording()`
- `stopRecording()`

**Usage**:

```swift
let audioEngine = AudioEngineManager.shared
audioEngine.startEngine()
```

### TranscriptionManager

**File**: `TranscriptionManager.swift`

**Description**: Handles the transcription data, including managing transcription history, saving/loading transcriptions, and sending them to a backend server.

**Key Methods**:

- `getTranscriptionHistory() -> [String]`
- `getLastTranscribedText() -> String`
- `sendTranscriptions(to url: URL, completion: @escaping (Result<Void, Error>) -> Void)`
- `sendZipOfTranscriptionsAndAudio(to url: URL, completion: @escaping (Result<Void, Error>) -> Void)`

**Usage**:

```swift
let transcriptionManager = TranscriptionManager.shared
transcriptionManager.sendTranscriptions(to: yourURL) { result in
    switch result {
    case .success():
        print("Transcriptions sent successfully.")
    case .failure(let error):
        print("Error sending transcriptions: \(error.localizedDescription)")
    }
}
```

### SpeechRecognitionManager

**File**: `SpeechRecognition.swift`

**Description**: Manages speech recognition tasks, converting audio buffers into transcriptions.

**Key Methods**:

- `startRecognition(audioBufferPublisher: AnyPublisher<AVAudioPCMBuffer, Never>)`
- `stopRecognition()`

**Usage**:

```swift
let speechManager = SpeechRecognitionManager()
speechManager.startRecognition(audioBufferPublisher: audioBufferPublisher)
```

### WebSocketManager

**File**: `SocketManager.swift`

**Description**: Manages WebSocket connections for live audio streaming. Handles sending and receiving audio data.

**Key Methods**:

- `sendAudioData(_ data: Data)`
- `setupWebSocket(url: URL)`

**Usage**:

```swift
let webSocketURL = URL(string: "wss://yourserver.com/audio")!
let webSocketManager = WebSocketManager(url: webSocketURL)
audioEngineManager.assignWebSocketManager(manager: webSocketManager)
```

### AudioState

**File**: `AudioState.swift`

**Description**: Central state management for audio functionalities, integrating recording, playback, transcriptions, and device management.

**Key Methods**:

- `toggleRecording(manual: Bool)`
- `startRecording(manual: Bool)`
- `stopRecording()`
- `togglePlayback()`
- `deleteRecording(_ recording: AudioRecording)`
- `updateLocalRecordings()`
- `fetchRecordings()`
- `formattedFileSize(bytes: Int64) -> String`
- `currentRecordingURL() -> URL?`

**Usage**:

```swift
let audioState = AudioState.shared
audioState.toggleRecording(manual: true)
```

### SoundMeasurementManager

**File**: `ASoundMeasurement.swift`

**Description**: Monitors and analyzes audio levels, handling background noise calibration and spike detection.

**Key Methods**:

- `handleAudioLevel(_ level: Float)`

**Usage**:

```swift
let soundMeasurement = SoundMeasurementManager.shared
soundMeasurement.handleAudioLevel(currentLevel)
```

### LocationManager

**File**: `ALocation.swift`

**Description**: Manages location tracking, integrating location data with audio recordings.

**Key Methods**:

- `requestLocationAuthorization()`
- `startSignificantChangeMonitoring()`
- `stopSignificantChangeMonitoring()`

**Usage**:

```swift
let locationManager = LocationManager.shared
locationManager.requestLocationAuthorization()
```

### AudioConverter

**File**: `AConverter.swift`

**Description**: Handles audio file format conversions, currently supporting `.caf` to `.wav` and vice versa.

**Key Methods**:

- `convertCAFToWAV(sourceURL: URL, destinationURL: URL) async throws`
- `convertWAVToCAF(sourceURL: URL, destinationURL: URL) async throws`

**Usage**:

```swift
do {
    try await AudioConverter.shared.convertCAFToWAV(sourceURL: sourceURL, destinationURL: destinationURL)
    print("Conversion successful.")
} catch {
    print("Conversion failed: \(error.localizedDescription)")
}
```

### AudioPlaybackManager

**File**: `AudioPlaybackManager.swift`

**Description**: Manages audio playback functionalities, including starting, pausing, and handling playback errors.

**Key Methods**:

- `startPlayback(for url: URL?)`
- `pausePlayback()`

**Usage**:

```swift
let playbackManager = AudioPlaybackManager()
playbackManager.startPlayback(for: recordingURL)
```

---

## Integration Steps

To integrate OpenAudio into your app, follow these steps:

1. **Initialize OpenAudioManager**:
   
    ```swift
    let audioManager = OpenAudioManager.shared
    ```

2. **Set Up WebSocket (Optional)**:

    If you intend to stream audio live, set up the WebSocket connection.

    ```swift
    let webSocketURL = URL(string: "wss://yourserver.com/audio")!
    audioManager.setupWebSocket(url: webSocketURL)
    ```

3. **Start Recording**:

    ```swift
    audioManager.startRecording(manual: true) // `manual` indicates user-initiated recording
    ```

4. **Stop Recording**:

    ```swift
    audioManager.stopRecording()
    ```

5. **Playback Recorded Audio**:

    ```swift
    audioManager.togglePlayback()
    ```

6. **Handle Transcriptions (Optional)**:

    Access transcriptions via `TranscriptionManager`.

    ```swift
    let transcriptionManager = TranscriptionManager.shared
    let history = transcriptionManager.getTranscriptionHistory()
    ```

7. **Manage Audio Devices (Optional)**:

    ```swift
    let deviceManager = DeviceManager.shared
    let newDevice = AudioDevice(name: "Microphone 1")
    deviceManager.addDevice(newDevice)
    deviceManager.startRecording(on: newDevice)
    ```

8. **Location Tracking (Optional)**:

    ```swift
    let locationManager = LocationManager.shared
    locationManager.requestLocationAuthorization()
    ```

---

## Usage Examples

### Starting and Stopping Recording

**Start Recording**:

```swift
import OpenAudio

// Access the shared manager
let audioManager = OpenAudioManager.shared

// Start recording manually initiated by the user
audioManager.startRecording(manual: true)
```

**Stop Recording**:

```swift
audioManager.stopRecording()
```

### Playback Control

**Toggle Playback**:

```swift
audioManager.togglePlayback()
```

**Direct Playback Using AudioPlaybackManager**:

```swift
import OpenAudio

let playbackManager = AudioPlaybackManager()
if let recordingURL = audioManager.currentRecordingURL() {
    playbackManager.startPlayback(for: recordingURL)
}
```

### Live Audio Streaming

**Set Up WebSocket and Start Streaming**:

```swift
import OpenAudio

let audioManager = OpenAudioManager.shared
let webSocketURL = URL(string: "wss://yourserver.com/audio")!
audioManager.setupWebSocket(url: webSocketURL)
audioManager.startStreaming()
```

**Stop Streaming**:

```swift
audioManager.stopStreaming()
```

### Transcription Handling

**Accessing Transcriptions**:

```swift
import OpenAudio

let transcriptionManager = TranscriptionManager.shared
let history = transcriptionManager.getTranscriptionHistory()
let latestTranscription = transcriptionManager.getLastTranscribedText()
```

**Sending Transcriptions to Backend**:

```swift
let transcriptionManager = TranscriptionManager.shared
let backendURL = URL(string: "https://yourserver.com/transcriptions")!
transcriptionManager.sendTranscriptions(to: backendURL) { result in
    switch result {
    case .success():
        print("Transcriptions sent successfully.")
    case .failure(let error):
        print("Error sending transcriptions: \(error.localizedDescription)")
    }
}
```

### Device Management

**Adding and Managing Devices**:

```swift
import OpenAudio

let deviceManager = DeviceManager.shared
let newDevice = AudioDevice(name: "External Mic")

// Add and connect the device
deviceManager.addDevice(newDevice)

// Start recording on the new device
deviceManager.startRecording(on: newDevice)

// Stop recording on the device
deviceManager.stopRecording(on: newDevice)
```

### Location Tracking

**Requesting Location Authorization and Starting Tracking**:

```swift
import OpenAudio

let locationManager = LocationManager.shared
locationManager.requestLocationAuthorization()
```

**Accessing Current Location**:

```swift
import OpenAudio

if let currentLocation = LocationManager.shared.currentLocation {
    print("Current Location: \(currentLocation.latitude ?? 0), \(currentLocation.longitude ?? 0)")
}
```

---

## API Reference

### OpenAudioManager

- **Properties**:
    - `shared`: Singleton instance.
- **Methods**:
    - `startRecording(manual: Bool = false)`
    - `stopRecording()`
    - `togglePlayback()`
    - `startStreaming()`
    - `stopStreaming()`
    - `setupWebSocket(url: URL)`

### AudioFileManager

- **Properties**:
    - `shared`: Singleton instance.
- **Methods**:
    - `getDocumentsDirectory() -> URL`
    - `updateLocalRecordings() -> [AudioRecording]`
    - `deleteRecording(_ recording: AudioRecording) throws`
    - `formattedDuration(_ duration: TimeInterval) -> String`
    - `formattedFileSize(bytes: Int64) -> String`
    - `saveTranscriptions(_ data: TranscriptionData)`
    - `loadTranscriptions() -> TranscriptionData?`
    - `sendTranscriptions(_ data: TranscriptionData, to url: URL, completion: @escaping (Result<Void, Error>) -> Void)`
    - `sendZipOfTranscriptionsAndAudio(to url: URL, completion: @escaping (Result<Void, Error>) -> Void)`
    - `sendAudioFiles(to url: URL, completion: @escaping (Result<Void, Error>) -> Void)`

### RecordingScript

- **Properties**:
    - `shared`: Singleton instance.
- **Methods**:
    - `startRecording()`
    - `stopRecording()`
    - `currentRecordingURL() -> URL?`
    - `currentTranscription() -> String`
    - `isFinalTranscription: Bool`

### DeviceManager

- **Properties**:
    - `shared`: Singleton instance.
    - `connectedDevices`: Published array of connected devices.
- **Methods**:
    - `addDevice(_ device: Device)`
    - `removeDevice(_ device: Device)`
    - `startRecording(on device: Device)`
    - `stopRecording(on device: Device)`
    - `startRecordingOnAllDevices()`
    - `stopRecordingOnAllDevices()`

### AudioEngineManager

- **Properties**:
    - `shared`: Singleton instance.
    - `isEngineRunning`: Indicates if the engine is active.
- **Methods**:
    - `assignWebSocketManager(manager: WebSocketManagerProtocol)`
    - `startEngine()`
    - `stopEngine()`
    - `startRecording()`
    - `stopRecording()`

### TranscriptionManager

- **Properties**:
    - `shared`: Singleton instance.
    - `transcriptionHistory`: Published array of past transcriptions.
    - `lastTranscribedText`: Published latest transcription.
- **Methods**:
    - `getTranscriptionHistory() -> [String]`
    - `getLastTranscribedText() -> String`
    - `sendTranscriptions(to url: URL, completion: @escaping (Result<Void, Error>) -> Void)`
    - `sendZipOfTranscriptionsAndAudio(to url: URL, completion: @escaping (Result<Void, Error>) -> Void)`

### SpeechRecognitionManager

- **Properties**:
    - `isSpeaking`: Published Bool indicating if speech is ongoing.
    - `transcription`: Published String of current transcription.
    - `errorMessage`: Published String? for errors.
- **Methods**:
    - `startRecognition(audioBufferPublisher: AnyPublisher<AVAudioPCMBuffer, Never>)`
    - `stopRecognition()`

### WebSocketManager

- **Properties**:
    - `receivedDataPublisher`: Publisher for incoming data.
- **Methods**:
    - `init(url: URL)`
    - `sendAudioData(_ data: Data)`

### AudioState

- **Properties**:
    - `shared`: Singleton instance.
    - `isRecording`, `isPlaying`, `recordingTime`, `recordingProgress`, `isPlaybackAvailable`, `errorMessage`, `localRecordings`, `currentRecording`: Published properties.
    - `isRecordingEnabled`, `isBackgroundRecordingEnabled`: Persistent settings.
- **Methods**:
    - `toggleRecording(manual: Bool)`
    - `startRecording(manual: Bool)`
    - `stopRecording()`
    - `togglePlayback()`
    - `deleteRecording(_ recording: AudioRecording)`
    - `updateLocalRecordings()`
    - `fetchRecordings()`
    - `formattedFileSize(bytes: Int64) -> String`
    - `currentRecordingURL() -> URL?`

### SoundMeasurementManager

- **Properties**:
    - `shared`: Singleton instance.
    - `currentAudioLevel`, `averageBackgroundNoise`, `isBackgroundNoiseReady`: Published properties.
- **Methods**:
    - `handleAudioLevel(_ level: Float)`

### LocationManager

- **Properties**:
    - `shared`: Singleton instance.
    - `currentLocation`: Published LocationData?
    - `locationErrorMessage`: Published String?
    - `locationPublisher`: Publisher for location updates.
- **Methods**:
    - `requestLocationAuthorization()`
    - `startSignificantChangeMonitoring()`
    - `stopSignificantChangeMonitoring()`

### AudioConverter

- **Properties**:
    - `shared`: Singleton instance.
- **Methods**:
    - `convertCAFToWAV(sourceURL: URL, destinationURL: URL) async throws`
    - `convertWAVToCAF(sourceURL: URL, destinationURL: URL) async throws`

### AudioPlaybackManager

- **Properties**:
    - `isPlaying`: Published Bool.
    - `errorMessage`: Published String?
- **Methods**:
    - `startPlayback(for url: URL?)`
    - `pausePlayback()`

---

## Integration Steps

Integrate OpenAudio into your SwiftUI application by following these steps:

1. **Import OpenAudio**:

    ```swift
    import OpenAudio
    ```

2. **Initialize OpenAudioManager**:

    ```swift
    let audioManager = OpenAudioManager.shared
    ```

3. **Set Up WebSocket for Live Streaming (Optional)**:

    ```swift
    let webSocketURL = URL(string: "wss://yourserver.com/audio")!
    audioManager.setupWebSocket(url: webSocketURL)
    ```

4. **Start Recording**:

    ```swift
    audioManager.startRecording(manual: true)
    ```

5. **Stop Recording**:

    ```swift
    audioManager.stopRecording()
    ```

6. **Playback Control**:

    ```swift
    audioManager.togglePlayback()
    ```

7. **Handle Transcriptions**:

    ```swift
    let transcriptionManager = TranscriptionManager.shared
    let history = transcriptionManager.getTranscriptionHistory()
    ```

8. **Manage Devices (Optional)**:

    ```swift
    let deviceManager = DeviceManager.shared
    let newDevice = AudioDevice(name: "External Mic")
    deviceManager.addDevice(newDevice)
    deviceManager.startRecording(on: newDevice)
    ```

9. **Location Tracking (Optional)**:

    ```swift
    let locationManager = LocationManager.shared
    locationManager.requestLocationAuthorization()
    ```

10. **Configure Audio Session (Handled by AudioState)**:

    The `AudioState` singleton manages audio session configurations and lifecycle events. Ensure it's initialized appropriately within your app.

---

## Usage Examples

### Starting and Stopping Recording

**Start Recording**:

```swift
import OpenAudio

// Access the shared manager
let audioManager = OpenAudioManager.shared

// Start recording manually initiated by the user
audioManager.startRecording(manual: true)
```

**Stop Recording**:

```swift
audioManager.stopRecording()
```

### Playback Control

**Toggle Playback**:

```swift
audioManager.togglePlayback()
```

**Direct Playback Using AudioPlaybackManager**:

```swift
import OpenAudio

let playbackManager = AudioPlaybackManager()
if let recordingURL = audioManager.currentRecordingURL() {
    playbackManager.startPlayback(for: recordingURL)
}
```

### Live Audio Streaming

**Set Up WebSocket and Start Streaming**:

```swift
import OpenAudio

let audioManager = OpenAudioManager.shared
let webSocketURL = URL(string: "wss://yourserver.com/audio")!
audioManager.setupWebSocket(url: webSocketURL)
audioManager.startStreaming()
```

**Stop Streaming**:

```swift
audioManager.stopStreaming()
```

### Transcription Handling

**Accessing Transcriptions**:

```swift
import OpenAudio

let transcriptionManager = TranscriptionManager.shared
let history = transcriptionManager.getTranscriptionHistory()
let latestTranscription = transcriptionManager.getLastTranscribedText()
```

**Sending Transcriptions to Backend**:

```swift
let transcriptionManager = TranscriptionManager.shared
let backendURL = URL(string: "https://yourserver.com/transcriptions")!
transcriptionManager.sendTranscriptions(to: backendURL) { result in
    switch result {
    case .success():
        print("Transcriptions sent successfully.")
    case .failure(let error):
        print("Error sending transcriptions: \(error.localizedDescription)")
    }
}
```

### Device Management

**Adding and Managing Devices**:

```swift
import OpenAudio

let deviceManager = DeviceManager.shared
let newDevice = AudioDevice(name: "External Mic")

// Add and connect the device
deviceManager.addDevice(newDevice)

// Start recording on the new device
deviceManager.startRecording(on: newDevice)
```

### Location Tracking

**Requesting Location Authorization and Starting Tracking**:

```swift
import OpenAudio

let locationManager = LocationManager.shared
locationManager.requestLocationAuthorization()
```

**Accessing Current Location**:

```swift
import OpenAudio

if let currentLocation = LocationManager.shared.currentLocation {
    print("Current Location: \(currentLocation.latitude ?? 0), \(currentLocation.longitude ?? 0)")
}
```

### Audio Conversion

**Convert `.caf` to `.wav`**:

```swift
import OpenAudio

let converter = AudioConverter.shared
let sourceURL = URL(fileURLWithPath: "/path/to/source.caf")
let destinationURL = URL(fileURLWithPath: "/path/to/destination.wav")

Task {
    do {
        try await converter.convertCAFToWAV(sourceURL: sourceURL, destinationURL: destinationURL)
        print("Conversion to WAV successful.")
    } catch {
        print("Conversion failed: \(error.localizedDescription)")
    }
}
```

**Convert `.wav` to `.caf`**:

```swift
let sourceURL = URL(fileURLWithPath: "/path/to/source.wav")
let destinationURL = URL(fileURLWithPath: "/path/to/destination.caf")

Task {
    do {
        try await converter.convertWAVToCAF(sourceURL: sourceURL, destinationURL: destinationURL)
        print("Conversion to CAF successful.")
    } catch {
        print("Conversion failed: \(error.localizedDescription)")
    }
}
```

---

## API Reference

### Protocols

#### `WebSocketManagerProtocol`

Defines the interface for WebSocket management.

- **Properties**:
    - `receivedDataPublisher: AnyPublisher<Data, Never>`
- **Methods**:
    - `sendAudioData(_ data: Data)`

#### `AudioEngineManagerProtocol`

Defines the interface for managing the audio engine.

- **Properties**:
    - `audioLevelPublisher: AnyPublisher<Float, Never>`
    - `audioBufferPublisher: AnyPublisher<AVAudioPCMBuffer, Never>`
    - `isEngineRunning: Bool`
- **Methods**:
    - `startEngine()`
    - `stopEngine()`
    - `assignWebSocketManager(manager: WebSocketManagerProtocol)`
    - `startRecording()`
    - `stopRecording()`

#### `RecordingManagerProtocol`

Defines the interface for recording management.

- **Properties**:
    - `isRecording: AnyPublisher<Bool, Never>`
    - `recordingTime: AnyPublisher<TimeInterval, Never>`
    - `recordingProgress: AnyPublisher<Double, Never>`
    - `errorMessage: AnyPublisher<String?, Never>`
- **Methods**:
    - `startRecording()`
    - `stopRecording()`
    - `currentRecordingURL() -> URL?`

#### `AudioStateProtocol`

Defines the observable state for audio functionalities.

- **Properties**:
    - Recording State: `isRecording`, `isRecordingEnabled`, `isBackgroundRecordingEnabled`
    - Playback State: `isPlaying`, `isPlaybackAvailable`
    - Recording Progress: `recordingTime`, `recordingProgress`
    - Current Recording: `currentRecording`
    - Error Handling: `errorMessage`
    - Audio Level: `audioLevelPublisher`, `formattedRecordingTime`
- **Methods**:
    - Recording Control: `setupWebSocket(manager: WebSocketManagerProtocol)`, `toggleRecording(manual: Bool)`, `stopRecording()`
    - Playback Control: `togglePlayback()`
    - Recording Management: `deleteRecording(_ recording: AudioRecording)`, `updateLocalRecordings()`, `fetchRecordings()`
    - Utility: `formattedFileSize(bytes: Int64) -> String`
    - Additional Recording Methods: `startRecording(manual: Bool)`, `currentRecordingURL() -> URL?`

---

## Best Practices

- **Handle Permissions Gracefully**: Always check and handle user permissions for microphone and location services.
  
    ```swift
    let audioSession = AVAudioSession.sharedInstance()
    switch audioSession.recordPermission {
    case .granted:
        // Proceed with recording
    case .denied:
        // Inform the user
    case .undetermined:
        // Request permission
    @unknown default:
        break
    }
    ```

- **Manage Audio Sessions Properly**: Ensure that audio sessions are correctly configured to prevent conflicts.

- **Use Singleton Instances Wisely**: OpenAudio components like `OpenAudioManager`, `AudioFileManager`, etc., are singletons. Use them consistently across your app to maintain a unified state.

- **Handle Backgrounding**: Utilize `AudioState` and `LifecycleManager` to manage audio tasks during app lifecycle changes.

- **Error Handling**: Implement robust error handling to manage failures gracefully and provide feedback to users.

- **Optimize Performance**: Avoid unnecessary recordings and manage resources efficiently, especially when dealing with multiple devices.

---

## Troubleshooting

**Issue**: *Recording not starting or stopping unexpectedly.*

- **Solution**:
    - Ensure microphone permissions are granted.
    - Check if the audio engine is running.
    - Verify that no other audio sessions are conflicting.

**Issue**: *Transcriptions are inaccurate or not appearing.*

- **Solution**:
    - Ensure speech recognition permissions are granted.
    - Check the network connectivity if using online recognition services.
    - Verify audio quality and ensure minimal background noise.

**Issue**: *WebSocket connection fails.*

- **Solution**:
    - Confirm the WebSocket URL is correct and the server is reachable.
    - Check network connectivity.
    - Implement reconnection logic in `WebSocketManager` if necessary.

**Issue**: *Playback does not work.*

- **Solution**:
    - Verify the recording file exists and is accessible.
    - Ensure the audio player is properly initialized.
    - Check for any playback-related errors via `errorMessage`.

**Issue**: *Location data not updating.*

- **Solution**:
    - Ensure location permissions are granted.
    - Verify that location services are enabled on the device.
    - Check if significant location change monitoring is active.

---

