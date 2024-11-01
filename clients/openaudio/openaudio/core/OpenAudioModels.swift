//
//  OpenAudioModels.swift
//  IRL
//
//  Created by Elijah Arbee on 10/25/24.
//

// ARecordingModel.swift
// openaudiostandard
//
// Created by Elijah Arbee on 10/23/24.
//

import Foundation

public struct AudioRecording: Identifiable {
    public let id: UUID
    public let url: URL
    public var isSpeechLikely: Bool?
    public var transcription: String? // Added transcription property
    
    public init(id: UUID = UUID(), url: URL, isSpeechLikely: Bool? = nil, transcription: String? = nil) {
        self.id = id
        self.url = url
        self.isSpeechLikely = isSpeechLikely
        self.transcription = transcription
    }
}


