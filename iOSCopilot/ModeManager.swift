//
//  ModeManager.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 7/29/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation

enum Mode: String, Codable {
    case Aggressive
    case Active
    case Background
    case Powersave
}

struct ModeSettings {
    // nil -> tracking disabled
    let trackingDistance: CLLocationDistance?
    let exerciseModeEnabled: Bool = false //TODO
}

class ModeController {
    private lazy var locationManager = AppDelegate.locationTracker
    private var currentMode: Mode = .Active
    
    @objc func powerStateChanged() {
        NSLog("Power state cahnged")
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            NSLog("Automatically entering low-power mode")
            self.setMode(mode: .Powersave)
            return
        }
        if currentMode == .Powersave {
            //TODO
        }
    }
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(powerStateChanged), name: NSNotification.Name.NSProcessInfoPowerStateDidChange, object: nil)
        self.powerStateChanged()
        //TODO
    }
    
    private func setAggressive() {
        self.locationManager?.startTracking()
        self.locationManager?.setTrackingLevel(distanceFilter: 500) // 500 meters
        //TODO
    }
    
    private func setActive() {
        self.locationManager?.setTrackingLevel(distanceFilter: 1000) // 1km
        self.locationManager?.startTracking()
        //TODO
    }
    
    private func setBackground() {
        self.locationManager?.startTracking()
        self.locationManager?.setTrackingLevel(distanceFilter: 5000) // 5km
        //TODO
    }
    
    private func setPowersave() {
        locationManager?.stopTracking()
        //TODO
    }
    
    func setMode(mode: Mode) {
        self.currentMode = mode
        NSLog("Setting mode \(mode)")
        switch mode {
        case .Active:
            self.setActive()
            break
        case .Aggressive:
            self.setAggressive()
            break
        case .Background:
            self.setBackground()
            break
        case .Powersave:
            self.setPowersave()
            break
        }
    }
    
    func getMode() -> Mode {
        return self.currentMode
    }
    
    static let shared = ModeController()
}

class ModeManagerViewController: UIViewController {
    private var defaultBackgroundColor: UIColor?
    @IBOutlet weak var modeButtons: UISegmentedControl!
    @IBAction func modeChanged(_ sender: UISegmentedControl) {
        NSLog("user selected new mode")
        let selectedMode = Mode(rawValue: sender.titleForSegment(at: sender.selectedSegmentIndex)!)!
        ModeController.shared.setMode(mode: selectedMode)
    }

    private func initMode() {
        let activeMode = ModeController.shared.getMode()
        NSLog("Initializing mode manager with mode \(activeMode)")
        DispatchQueue.main.async {
            if activeMode == .Powersave {
                self.view.backgroundColor = UIColor.red
            } else {
                self.view.backgroundColor = self.defaultBackgroundColor
            }
        }
        // Disable buttons until initialized to correct current value
        DispatchQueue.main.async {
            self.modeButtons.isEnabled = false
        }
        let numSegments = self.modeButtons.numberOfSegments
        for  segment in 0...(numSegments - 1) {
            let title = self.modeButtons.titleForSegment(at: segment)!
            if Mode(rawValue: title)! == activeMode {
                DispatchQueue.main.async {
                    self.modeButtons.selectedSegmentIndex = segment
                    self.modeButtons.isEnabled = true
                }
            }
        }
    }
    
    override func viewDidLoad() {
        self.defaultBackgroundColor = self.view.backgroundColor
        self.initMode()
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.initMode()
        super.viewDidAppear(animated)
    }
}
