//
//  AudioAlerts.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 2/14/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import AVFoundation

class VoiceSynth: NSObject, AVSpeechSynthesizerDelegate {
    private let voice: AVSpeechSynthesisVoice
    private let synth: AVSpeechSynthesizer
    private let session: AVAudioSession
    
    private override init() {
        self.session = AVAudioSession.sharedInstance()
        try? session.setCategory(AVAudioSessionCategoryPlayback, with: .duckOthers)
        self.voice = AVSpeechSynthesisVoice(language: "en-gb")!
        self.synth = AVSpeechSynthesizer()
        super.init()
        self.synth.delegate = self
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        try? session.setActive(true)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        try? session.setActive(false)
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
