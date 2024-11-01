// ADeviceManager.swift
// openaudiostandard
//
// Created by Elijah Arbee on 10/23/24.
//

import Foundation
import Combine
import AVFoundation

public class AudioDevice: Device {
    public let identifier: UUID
    public let name: String
    public var isConnected: Bool = false
    public var isRecording: Bool = false
    
    private var audioEngineManager: AudioEngineManagerProtocol
    
    public var onStateChange: ((Bool, Bool) -> Void)?
    
    // Inject AudioEngineManagerProtocol
    public init(name: String, audioEngineManager: AudioEngineManagerProtocol) {
        self.identifier = UUID()
        self.name = name
        self.audioEngineManager = audioEngineManager
    }
    
    public func connect() {
        isConnected = true
        onStateChange?(isConnected, isRecording)
        print("\(name) connected.")
    }
    
    public func disconnect() {
        isConnected = false
        isRecording = false
        onStateChange?(isConnected, isRecording)
        print("\(name) disconnected.")
    }
    
    public func startRecording() {
        guard isConnected else { return }
        AVAudioSessionManager.shared.configureForBackgroundRecording()
        audioEngineManager.startRecording()
        isRecording = true
        onStateChange?(isConnected, isRecording)
        print("Recording started on \(name).")
    }
    
    public func stopRecording() {
        guard isConnected else { return }
        audioEngineManager.stopRecording()
        AVAudioSessionManager.shared.deactivateAudioSession()
        isRecording = false
        onStateChange?(isConnected, isRecording)
        print("Recording stopped on \(name).")
    }
    
    public func currentRecordingURL() -> URL? {
        return audioEngineManager.currentAudioFileURL
    }
}


//
//  DeviceManagerProtocol.swift
//  irlapp
//
//  Created by Elijah Arbee on 10/29/24.
//

import Foundation

/// Protocol defining the interface for managing device-related information.
import Foundation

/// Protocol defining the interface for managing device-related information.
public protocol DeviceManagerProtocol: AnyObject {
    /// The current device's unique identifier.
    var currentDeviceID: UUID? { get }
    
    /// Connects a given device.
    func connectDevice(_ device: Device)
    
    /// Disconnects a given device.
    func disconnectDevice(_ device: Device)
    
    // Add other device-related methods and properties as needed.
}


// MARK: - Device Protocol

/// A protocol defining the interface for audio devices.
public protocol Device: AnyObject {
    /// A unique identifier for the device.
    var identifier: UUID { get }
    
    /// The name of the device.
    var name: String { get }
    
    /// Indicates whether the device is currently connected.
    var isConnected: Bool { get set }
    
    /// Indicates whether the device is currently recording.
    var isRecording: Bool { get set }
    
    /// Connects the device.
    func connect()
    
    /// Disconnects the device.
    func disconnect()
    
    /// Starts recording on the device.
    func startRecording()
    
    /// Stops recording on the device.
    func stopRecording()
}
