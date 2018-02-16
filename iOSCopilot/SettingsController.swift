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
    
    @IBAction func locationPrivacyChanged(_ sender: Any) {
        LocationTracker.shared.privacyEnabled = locationPrivacyButton.isOn
        NSLog("Set location privacy to \(locationPrivacyButton.isOn)")
    }
    //TODO
}
