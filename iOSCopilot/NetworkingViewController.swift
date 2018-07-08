//
//  NetworkingViewController.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 7/7/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import UIKit

class NetworkingViewController: UIViewController {
    private let meshNetwork = MeshNetwork(isBaseStation: false)
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.meshNetwork.startAdvertising()
        NSLog("Advertising mesh")
        //TODO
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.meshNetwork.stopAdvertising()
        NSLog("Not advertising mesh")
    }
    //TODO
}
