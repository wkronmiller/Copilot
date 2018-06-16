//
//  CommsController.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 6/4/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import PushKit
import MultipeerConnectivity
import TwilioVoice

class CommsService: NSObject, AVAudioRecorderDelegate {
    private let audioSession = AVAudioSession.sharedInstance()
    
    func record() {
        do {
            try self.audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
            try self.audioSession.setActive(true)
        } catch {
            NSLog("Cannot initialize recording session")
            return
        }

    }
    
    static let shared = CommsService()
}

class CommsController: UIViewController {
    private let comms = CommsService.shared
    
    @IBAction func callButtonClicked() {
        NSLog("Recording")
        comms.record()
        //TODO
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
    }
    
}
