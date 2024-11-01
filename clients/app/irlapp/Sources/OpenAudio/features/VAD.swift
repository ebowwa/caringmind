//
//  VAD.swift
//  irlapp
//
//  Created by Elijah Arbee on 10/30/24.
//

import Foundation
import AVFoundation

/// A protocol defining the interface for Voice Activity Detection.
public protocol VoiceActivityDetectorProtocol: AnyObject {
    /// Determines whether the given audio buffer contains speech.
    /// - Parameter buffer: The audio buffer to analyze.
    /// - Returns: `true` if speech is detected; otherwise, `false`.
    func isSpeech(buffer: AVAudioPCMBuffer) -> Bool
}

/// A default implementation of Voice Activity Detection using an energy-based algorithm.
public class EnergyBasedVoiceActivityDetector: VoiceActivityDetectorProtocol {
    
    // MARK: - Properties
    
    /// The energy threshold above which the buffer is considered to contain speech.
    private let energyThreshold: Float
    
    /// Number of consecutive frames required to confirm speech presence.
    private let consecutiveSpeechFrames: Int
    
    /// Counter for consecutive speech frames.
    private var speechFrameCounter: Int = 0
    
    // MARK: - Initialization
    
    /// Initializes the EnergyBasedVoiceActivityDetector with configurable parameters.
    /// - Parameters:
    ///   - energyThreshold: The energy level threshold. Defaults to -30.0 dB.
    ///   - consecutiveSpeechFrames: Number of consecutive frames to confirm speech. Defaults to 3.
    public init(energyThreshold: Float = -30.0, consecutiveSpeechFrames: Int = 3) {
        self.energyThreshold = energyThreshold
        self.consecutiveSpeechFrames = consecutiveSpeechFrames
    }
    
    // MARK: - VoiceActivityDetectorProtocol
    
    public func isSpeech(buffer: AVAudioPCMBuffer) -> Bool {
        guard let channelData = buffer.floatChannelData?[0] else { return false }
        let frameLength = Int(buffer.frameLength)
        
        // Calculate RMS
        let rms = calculateRMS(channelData: channelData, frameCount: frameLength)
        
        // Convert RMS to decibels
        let avgPower = 20 * log10(rms)
        
        // Check against threshold
        if avgPower > energyThreshold {
            speechFrameCounter += 1
            if speechFrameCounter >= consecutiveSpeechFrames {
                speechFrameCounter = 0
                return true
            }
        } else {
            speechFrameCounter = 0
        }
        
        return false
    }
    
    // MARK: - Private Methods
    
    /// Calculates the Root Mean Square (RMS) of the audio signal.
    /// - Parameters:
    ///   - channelData: Pointer to the audio samples.
    ///   - frameCount: Number of frames in the buffer.
    /// - Returns: The RMS value.
    private func calculateRMS(channelData: UnsafeMutablePointer<Float>, frameCount: Int) -> Float {
        // Step 1: Extract the relevant samples
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        
        // Step 2: Calculate the sum of squares
        let sumOfSquares = samples.reduce(0) { $0 + ($1 * $1) }
        
        // Step 3: Calculate the mean of the squares
        let meanSquare = sumOfSquares / Float(frameCount)
        
        // Step 4: Calculate the root mean square (RMS)
        let rms = sqrt(meanSquare)
        
        return rms
    }
}
