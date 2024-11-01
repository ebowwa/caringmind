// AVAudioSessionManager.swift
// openaudiostandard
//
// Created by Elijah Arbee on 10/27/24.
// Follow-up for controlling audio route: https://chatgpt.com/share/671eb956-8860-800f-b7c6-133de40b6f72

import AVFoundation
import Foundation

// MARK: - AVAudioSessionManagerDelegate

public protocol AVAudioSessionManagerDelegate: AnyObject {
    func audioSessionConfigured(
        category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    )
    func audioSessionDeactivated()
    func audioSessionInterrupted()
    func audioSessionResumed()
}

/// AVAudioSessionManager centralizes the configuration and management of the AVAudioSession.
public class AVAudioSessionManager: NSObject, AVAudioSessionManagerProtocol {
    
    // MARK: - Singleton Instance
    public static let shared = AVAudioSessionManager()
    
    // MARK: - Properties
    public private(set) var currentCategory: AVAudioSession.Category?
    public private(set) var currentMode: AVAudioSession.Mode?
    public private(set) var currentOptions: AVAudioSession.CategoryOptions?
    
    public weak var delegate: AVAudioSessionManagerDelegate?
    
    private let audioSession = AVAudioSession.sharedInstance()
    
    // MARK: - Initialization
    private override init() {
        super.init()
        NotificationCenterHelper.setupInterruptionNotifications(for: self, selector: #selector(handleInterruption(notification:)))
    }
    
    // MARK: - Audio Session Configuration
    public func configureAudioSession(
        category: AVAudioSession.Category = .playAndRecord,
        mode: AVAudioSession.Mode = .default,
        options: AVAudioSession.CategoryOptions = [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker, .mixWithOthers]
    ) -> Result<Void, Error> {
        do {
            try audioSession.setCategory(category, mode: mode, options: options)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Update current settings and notify delegate
            currentCategory = category
            currentMode = mode
            currentOptions = options
            delegate?.audioSessionConfigured(category: category, mode: mode, options: options)
            
            return .success(())
        } catch {
            print("[AVAudioSessionManager] Failed to configure audio session: \(error.localizedDescription)")
            return .failure(error)
        }
    }
    
    public func deactivateAudioSession() -> Result<Void, Error> {
        do {
            try audioSession.setActive(false)
            delegate?.audioSessionDeactivated()
            
            // Reset current settings
            currentCategory = nil
            currentMode = nil
            currentOptions = nil
            
            return .success(())
        } catch {
            print("[AVAudioSessionManager] Failed to deactivate audio session: \(error.localizedDescription)")
            return .failure(error)
        }
    }
    
    // MARK: - Background Configuration
    public func configureForBackgroundRecording() {
        _ = configureAudioSession(
            category: .playAndRecord,
            mode: .default,
            options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker, .mixWithOthers]
        )
        print("[AVAudioSessionManager] Configured audio session for background recording.")
    }
    
    // MARK: - Interruption Handling
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let interruptionTypeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: interruptionTypeValue) else {
            return
        }
        
        switch interruptionType {
        case .began:
            print("[AVAudioSessionManager] Audio session interruption began.")
            _ = deactivateAudioSession()
            delegate?.audioSessionInterrupted()
            
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt,
               AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume),
               let category = currentCategory, let mode = currentMode, let options = currentOptions {
                _ = configureAudioSession(category: category, mode: mode, options: options)
                delegate?.audioSessionResumed()
            } else {
                _ = configureAudioSession()
            }
            
        @unknown default:
            print("[AVAudioSessionManager] Unknown audio session interruption type.")
        }
    }
    
    // MARK: - Deinitialization
    deinit {
        NotificationCenterHelper.removeInterruptionNotifications(for: self)
    }
}

// MARK: - Notification Center Helper
private struct NotificationCenterHelper {
    
    static func setupInterruptionNotifications(for observer: Any, selector: Selector) {
        NotificationCenter.default.addObserver(
            observer,
            selector: selector,
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        print("[NotificationCenterHelper] Audio session interruption notifications set up.")
    }
    
    static func removeInterruptionNotifications(for observer: Any) {
        NotificationCenter.default.removeObserver(
            observer,
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        print("[NotificationCenterHelper] Audio session interruption notifications removed.")
    }
}
