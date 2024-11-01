//
//  DeviceManager.swift
//  openaudiostandard
//
//  Created by Elijah Arbee on 10/23/24.
//

import Foundation
import Combine
import AVFoundation

public class AudioDevice: Device {
    public let identifier: UUID
    public let name: String
    public var isConnected: Bool = false
    public var isRecording: Bool = false

    private var audioState: AudioState
    private var recordingScript: RecordingScript

    // Use the singleton instance of RecordingScript
    public init(name: String, audioState: AudioState = .shared) {
        self.identifier = UUID()
        self.name = name
        self.audioState = audioState
        self.recordingScript = RecordingScript.shared // Access the singleton instance
    }

    public func connect() {
        isConnected = true
        print("\(name) connected.")
    }

    public func disconnect() {
        isConnected = false
        print("\(name) disconnected.")
    }

    public func startRecording() {
        guard isConnected else { return }
        recordingScript.startRecording() // Use RecordingScript for recording functionality
        isRecording = true
        print("Recording started on \(name).")
    }

    public func stopRecording() {
        guard isConnected else { return }
        recordingScript.stopRecording() // Use RecordingScript for stopping recording
        isRecording = false
        print("Recording stopped on \(name).")
    }

    // Optionally expose current recording URL if needed
    public func currentRecordingURL() -> URL? {
        return recordingScript.currentRecordingURL()
    }
}

public class DeviceManager: ObservableObject {
    @Published private(set) public var connectedDevices: [Device] = []

    // Singleton instance for global access.
    public static let shared = DeviceManager()

    private init() {}
    
    // MARK: - Device Management
    
    /// Adds a new device to the manager and connects it.
    public func addDevice(_ device: Device) {
        connectedDevices.append(device)
        device.connect()
    }

    /// Removes a device from the manager and disconnects it.
    public func removeDevice(_ device: Device) {
        device.disconnect()
        if let index = connectedDevices.firstIndex(where: { $0.identifier == device.identifier }) {
            connectedDevices.remove(at: index)
        }
    }

    // MARK: - Recording Controls
    
    /// Starts recording on a specific device.
    public func startRecording(on device: Device) {
        device.startRecording()
    }

    /// Stops recording on a specific device.
    public func stopRecording(on device: Device) {
        device.stopRecording()
    }

    /// Starts recording on all connected devices.
    public func startRecordingOnAllDevices() {
        for device in connectedDevices where device.isConnected {
            device.startRecording()
        }
    }

    /// Stops recording on all connected devices.
    public func stopRecordingOnAllDevices() {
        for device in connectedDevices where device.isConnected {
            device.stopRecording()
        }
    }
}
