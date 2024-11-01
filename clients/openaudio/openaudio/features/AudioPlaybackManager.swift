//
//  AudioPlaybackManager.swift
//  openaudiostandard
//
//  Created by Elijah Arbee on 10/23/24.
//

import Foundation
import AVFoundation
import Combine

public class AudioPlaybackManager: NSObject, AVAudioPlayerDelegate, ObservableObject {
    
    // Published properties
    @Published public private(set) var isPlaying: Bool = false
    @Published public var errorMessage: String?
    
    // Private properties
    private var audioPlayer: AVAudioPlayer?
    
    // Initialization
    public override init() {
        super.init()
    }
    
    // Start Playback
    public func startPlayback(for url: URL?) {
        guard let url = url else {
            errorMessage = "Invalid audio URL."
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
        } catch {
            errorMessage = "Error starting playback: \(error.localizedDescription)"
            print("AudioPlaybackManager Error: \(error.localizedDescription)")
        }
    }
    
    // Pause Playback
    public func pausePlayback() {
        guard isPlaying else { return }
        audioPlayer?.pause()
        isPlaying = false
    }
    
    // AVAudioPlayerDelegate Methods
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        if !flag {
            errorMessage = "Playback did not finish successfully."
        }
    }
    
    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            errorMessage = "Playback decode error: \(error.localizedDescription)"
            isPlaying = false
        }
    }
}
