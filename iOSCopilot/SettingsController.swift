//
//  SettingsController.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 2/15/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import UIKit

class SettingsController: UIViewController {
    @IBOutlet weak var voiceAlertsButton: UISwitch!
    @IBOutlet weak var locationPrivacyButton: UISwitch!
    
    override func viewDidAppear(_ animated: Bool) {
        DispatchQueue.main.async {
            self.voiceAlertsButton.isOn = Configuration.shared.audioAlertsEnabled
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    @IBAction func audioAlertsChanged(_ sender: Any) {
        Configuration.shared.audioAlertsEnabled = self.voiceAlertsButton.isOn
    }
    
    @IBAction func locationPrivacyChanged(_ sender: Any) {
        AppDelegate.locationTracker!.privacyEnabled = locationPrivacyButton.isOn
        NSLog("Set location privacy to \(locationPrivacyButton.isOn)")
    }
    //TODO
}
