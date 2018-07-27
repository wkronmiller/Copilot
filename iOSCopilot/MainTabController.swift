//
//  TabBarController.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 2/11/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import UIKit

class MainTabBarItem: UITabBarItem {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.titlePositionAdjustment = UIOffsetMake(0, -16)
    }
}

class MainTabBar: UITabBar {
}

class MainTabController: UITabBarController {
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tabBarItem.image = nil
        
        if Configuration.shared.getEnableMeshNetworking() == false {
            viewControllers?.popLast() //TODO: something position-independent that doesen't require app restart
        }
    }
}
