// LifecycleManager.swift
// irlapp
//
// Created by Elijah Arbee on 10/26/24.

import Foundation
import UIKit
import Combine
import ReSwift
import AVFoundation

// MARK: - AVAudioSessionManagerProtocol

public protocol AVAudioSessionManagerProtocol: AnyObject {
    var currentCategory: AVAudioSession.Category? { get }
    var currentMode: AVAudioSession.Mode? { get }
    var currentOptions: AVAudioSession.CategoryOptions? { get }
    var delegate: AVAudioSessionManagerDelegate? { get set }
    
    func configureAudioSession(
        category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) -> Result<Void, Error>
    
    func deactivateAudioSession() -> Result<Void, Error>
    func configureForBackgroundRecording()
}

// MARK: - AudioLifecycleManager

public class AudioLifecycleManager: StoreSubscriber {
    // Inject dependencies
    private let store: Store<AppState>
    private let audioSessionManager: AVAudioSessionManagerProtocol
    private var cancellables: Set<AnyCancellable> = []
    
    public init(store: Store<AppState>, audioSessionManager: AVAudioSessionManagerProtocol) {
        self.store = store
        self.audioSessionManager = audioSessionManager
        setupLifecycle()
    }
    
    private func setupLifecycle() {
        setupAudioSession()
        setupNotifications()
        setupBindings()
    }
    
    private func setupAudioSession() {
        _ = audioSessionManager.configureAudioSession(
            category: .playAndRecord,
            mode: .default,
            options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker, .mixWithOthers]
        )
    }
    
    private func setupNotifications() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppBackgrounding), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppTermination), name: UIApplication.willTerminateNotification, object: nil)
        #endif
    }
    
    private func setupBindings() {
        // Subscribe to store changes and update accordingly
        store.subscribe(self) { $0.select { $0.audioSession } }
    }
    
    @objc private func handleAppBackgrounding() {
        // Dispatch actions or handle state changes
        store.dispatch(AudioSessionInterruptedAction())
    }
    
    @objc private func handleAppTermination() {
        // Dispatch actions or handle state changes
        store.dispatch(DeactivateAudioSessionAction())
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        store.unsubscribe(self)
    }
    
    // Conform to StoreSubscriber
    public func newState(state: AudioSessionState) {
        // Handle state updates
        if state.isActive {
            _ = audioSessionManager.configureAudioSession(
                category: convertCategory(state.category),
                mode: convertMode(state.mode),
                options: convertOptions(state.options)
            )
        } else {
            _ = audioSessionManager.deactivateAudioSession()
        }
    }
    
    // Helper methods to convert from custom types to AVFoundation types
    private func convertCategory(_ category: AudioSessionCategory) -> AVAudioSession.Category {
        switch category {
        case .ambient: return .ambient
        case .soloAmbient: return .soloAmbient
        case .playback: return .playback
        case .record: return .record
        case .playAndRecord: return .playAndRecord
        case .multiRoute: return .multiRoute
        }
    }
    
    private func convertMode(_ mode: AudioSessionMode) -> AVAudioSession.Mode {
        switch mode {
        case .default: return .default
        case .gameChat: return .gameChat
        case .measurement: return .measurement
        case .moviePlayback: return .moviePlayback
        case .spokenAudio: return .spokenAudio
        }
    }
    
    private func convertOptions(_ options: AudioSessionOptions) -> AVAudioSession.CategoryOptions {
        var avOptions: AVAudioSession.CategoryOptions = []
        if options.contains(.allowBluetooth) {
            avOptions.insert(.allowBluetooth)
        }
        if options.contains(.allowBluetoothA2DP) {
            avOptions.insert(.allowBluetoothA2DP)
        }
        if options.contains(.defaultToSpeaker) {
            avOptions.insert(.defaultToSpeaker)
        }
        if options.contains(.mixWithOthers) {
            avOptions.insert(.mixWithOthers)
        }
        return avOptions
    }
}
