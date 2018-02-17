//
//  AudioAlerts.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 2/14/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import AVFoundation

class VoiceSynth: NSObject {
    private let voice: AVSpeechSynthesisVoice
    private let synth: AVSpeechSynthesizer
    
    private override init() {
        self.voice = AVSpeechSynthesisVoice(language: "en-gb")!
        self.synth = AVSpeechSynthesizer()
        super.init()
    }
    
    func speak(phrases: String) {
        let utterance = AVSpeechUtterance(string: phrases)
        utterance.voice = self.voice
        
        guard synth.isSpeaking else {
            synth.speak(utterance)
            return
        }
    }
    
    static let shared = VoiceSynth()
}

