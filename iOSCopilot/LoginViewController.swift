//
//  LoginViewController.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 7/15/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import UIKit

class LoginViewController: UIViewController {
    @IBOutlet weak var userName: UITextField!
    @IBOutlet weak var password: UITextField!
    @IBAction func loginClicked(_ sender: Any) {
        Configuration.shared.setAccount(username: userName.text!, password: password.text!)
        NSLog("User entered credentials")
        // Configure location tracker
        AppDelegate.locationTracker = LocationTracker.get(account: Configuration.shared.getAccount()!)
        UIApplication.shared.delegate?.window??.rootViewController = UIStoryboard(name: "Main", bundle: Bundle.main).instantiateInitialViewController()
    }
}
