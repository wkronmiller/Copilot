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

class CommsContorller: UIViewController, TVOCallDelegate {
    
    private var call: TVOCall? = nil
    
    func callDidConnect(_ call: TVOCall) {
        NSLog("Call connected \(call)")
    }
    
    func call(_ call: TVOCall, didFailToConnectWithError error: Error) {
        NSLog("Call could not connect \(call) \(error)")
        self.call = nil
    }
    
    func call(_ call: TVOCall, didDisconnectWithError error: Error?) {
        if let failure = error {
            NSLog("Call dropped \(call) \(failure)")
        } else {
            NSLog("Call ended \(call)")
        }
        self.call = nil
    }
    
    @IBAction func callButtonClicked() {
        if let existing = self.call {
            NSLog("Hanging up")
            existing.disconnect()
            self.call = nil
        } else {
            self.call = TwilioVoice.call("TODO", params: nil, delegate: self)
            NSLog("Calling \(self.call)")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
    }
    
}
