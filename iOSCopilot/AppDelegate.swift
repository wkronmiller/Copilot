//
//  AppDelegate.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 2/4/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import UIKit
import AVFoundation
import UserNotifications

// http://paletton.com/#uid=14H0u0kllllaFw0g0qFqFg0w0aF

// Weather icons - https://www.uplabs.com/posts/material-design-weather-icon-set

// Badge icon - https://material.io/icons/#ic_security

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    static var locationTracker: LocationTracker? = nil

    private func configureTabBar() {
        let normalTitleAttributes = [
            NSAttributedStringKey.foregroundColor: UIColor.white,
            NSAttributedStringKey.font: UIFont(name: "Helvetica", size: 15.0)
        ]
        UITabBarItem.appearance().setTitleTextAttributes(normalTitleAttributes, for: UIControlState.normal)
        
        let selectedTitleAttributes = [
            NSAttributedStringKey.foregroundColor: UIColor.purple,
            NSAttributedStringKey.font: UIFont(name: "Helvetica", size: 15.0)
        ]
        UITabBarItem.appearance().setTitleTextAttributes(selectedTitleAttributes, for: UIControlState.selected)
        
    }
    
    private func configureNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .alert, .sound], completionHandler: {(granted, error) in
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        })
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        
        let deviceTokenString = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})
        NSLog("Device notification token \(deviceTokenString)")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NSLog("Failed to register for notifications \(error)")
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        self.configureTabBar()
        self.configureNotifications()
        //TODO: Login screen
        if let account = Configuration.shared.getAccount() {
            AppDelegate.locationTracker = LocationTracker.get(account: account)
        } else {
            application.delegate?.window??.rootViewController = UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(withIdentifier: "LoginViewController")
            NSLog("Unable to get account")
        }
        
        BiometricTracker.shared.authorize()
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

