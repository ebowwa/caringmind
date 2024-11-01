//
//  ASoundMeasurement.swift
//  openaudiostandard
//
//  Created by Elijah Arbee on 10/23/24.
// ALGORTHYMS TO INTEGRATE - https://chatgpt.com/share/672153cb-b238-800f-ad62-d423902b3b63

import Foundation
import Combine
import AVFoundation

// MARK: - Constants for SoundMeasurement
private enum SoundMeasurementConstants {
    static let emaAlpha: Double = 0.1
    static let noiseChangeThreshold: Double = 0.05
    static let spikeDurationThreshold: TimeInterval = 5.0  // Duration to consider as a sustained spike
    static let spikeLevelThreshold: Double = 0.3  // Adjust this to define what level is considered a spike
}

// MARK: - AudioUtils

public struct AudioUtils {
    /// Normalizes audio level from decibels to a range between 0 and 1
    public static func normalizeAudioLevel(_ level: Float) -> Double {
        let minDb: Float = -80.0
        let maxDb: Float = 0.0
        let clampedLevel = max(min(level, maxDb), minDb)
        return Double((clampedLevel - minDb) / (maxDb - minDb))
    }
}

// MARK: - SoundMeasurementManager

public class SoundMeasurementManager: ObservableObject {
    // MARK: - Dependencies
    private var audioEngineManager: AudioEngineManagerProtocol

    // MARK: - Published Properties
    @Published public var currentAudioLevel: Double = 0.0
    @Published public var averageBackgroundNoise: Double = 0.0
    @Published public var isBackgroundNoiseReady: Bool = false

    // MARK: - Persistent Storage Properties
    private let userDefaults = UserDefaults.standard
    private let isBackgroundNoiseCalibratedKey = "isBackgroundNoiseCalibrated"
    private let averageBackgroundNoisePersistedKey = "averageBackgroundNoisePersisted"

    public var isBackgroundNoiseCalibrated: Bool {
        get { userDefaults.bool(forKey: isBackgroundNoiseCalibratedKey) }
        set { userDefaults.set(newValue, forKey: isBackgroundNoiseCalibratedKey) }
    }

    public var averageBackgroundNoisePersisted: Double {
        get { userDefaults.double(forKey: averageBackgroundNoisePersistedKey) }
        set { userDefaults.set(newValue, forKey: averageBackgroundNoisePersistedKey) }
    }

    // MARK: - Private Properties
    private var backgroundNoiseLevels: [Double] = []
    private var spikeStartTime: Date?
    private var isRecalibrating: Bool = false
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - Initialization

    /// Initializes the SoundMeasurementManager with required dependencies.
    /// - Parameter audioEngineManager: An instance conforming to `AudioEngineManagerProtocol`.
    public init(audioEngineManager: AudioEngineManagerProtocol) {
        self.audioEngineManager = audioEngineManager
        setupBindings()
        loadPersistedNoise()
    }

    // MARK: - Setup Bindings

    private func setupBindings() {
        // Subscribe to audio level updates from AudioEngineManager
        audioEngineManager.audioLevelPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.handleAudioLevel(level)
            }
            .store(in: &cancellables)
        
        // Removed subscription to SpeechRecognitionManager's isSpeechDetected
    }

    // MARK: - Load Persisted Noise

    private func loadPersistedNoise() {
        if isBackgroundNoiseCalibrated {
            averageBackgroundNoise = averageBackgroundNoisePersisted
            isBackgroundNoiseReady = true
            print("Loaded persisted average background noise: \(averageBackgroundNoise)")
        } else {
            averageBackgroundNoise = 0.0
            isBackgroundNoiseReady = false
            print("Background noise not calibrated yet.")
        }
    }

    // MARK: - Audio Level Handling

    public func handleAudioLevel(_ level: Float) {
        let normalizedLevel = AudioUtils.normalizeAudioLevel(level)
        
        backgroundNoiseLevels.append(normalizedLevel)
        if !isBackgroundNoiseCalibrated {
            computeAverageBackgroundNoise()
        } else {
            updateNoiseIfCalibrated(normalizedLevel)
            detectNoiseSpikes(normalizedLevel)
        }
        
        adjustCurrentAudioLevelIfReady(normalizedLevel)
    }

    private func resetBackgroundNoiseCollection() {
        backgroundNoiseLevels.removeAll()
        spikeStartTime = nil
        // Do not reset averageBackgroundNoise
        isRecalibrating = false
        print("Background noise collection reset.")
    }

    private func computeAverageBackgroundNoise() {
        guard !backgroundNoiseLevels.isEmpty else { return }
        let average = backgroundNoiseLevels.reduce(0, +) / Double(backgroundNoiseLevels.count)
        DispatchQueue.main.async {
            self.updateBackgroundNoise(average)
        }
    }

    private func updateBackgroundNoise(_ average: Double) {
        averageBackgroundNoise = average
        averageBackgroundNoisePersisted = average
        isBackgroundNoiseCalibrated = true
        isBackgroundNoiseReady = true
        spikeStartTime = nil
        isRecalibrating = false
        print("Average Background Noise Updated: \(averageBackgroundNoisePersisted)")
    }

    private func updateNoiseIfCalibrated(_ normalizedLevel: Double) {
        let newEma = (SoundMeasurementConstants.emaAlpha * averageBackgroundNoisePersisted) + ((1 - SoundMeasurementConstants.emaAlpha) * normalizedLevel)
        let change = abs(newEma - averageBackgroundNoisePersisted)
        if change > SoundMeasurementConstants.noiseChangeThreshold {
            updateBackgroundNoise(newEma)
        }
    }

    private func adjustCurrentAudioLevelIfReady(_ normalizedLevel: Double) {
        let alpha: Double = 0.3 // Tweak this value to control noise influence
        if isBackgroundNoiseReady && !isRecalibrating && averageBackgroundNoisePersisted > 0.0 {
            let adjustedLevel = max(normalizedLevel - alpha * averageBackgroundNoisePersisted, 0.0)
            currentAudioLevel = adjustedLevel / (1.0 - alpha * averageBackgroundNoisePersisted)
        } else {
            currentAudioLevel = normalizedLevel
        }
    }

    // MARK: - Noise Spike Detection

    private func detectNoiseSpikes(_ normalizedLevel: Double) {
        if normalizedLevel > SoundMeasurementConstants.spikeLevelThreshold {
            if spikeStartTime == nil {
                spikeStartTime = Date()
                print("Noise spike started at: \(spikeStartTime!)")
            } else if let startTime = spikeStartTime, Date().timeIntervalSince(startTime) > SoundMeasurementConstants.spikeDurationThreshold {
                if !isRecalibrating {
                    isRecalibrating = true
                    print("Noise spike detected for \(SoundMeasurementConstants.spikeDurationThreshold) seconds, resetting background noise collection.")
                    resetBackgroundNoiseCollection()
                }
            }
        } else {
            spikeStartTime = nil
        }
    }
}

