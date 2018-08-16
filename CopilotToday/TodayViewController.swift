//
//  TodayViewController.swift
//  CopilotToday
//
//  Created by William Rory Kronmiller on 7/27/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import UIKit
import NotificationCenter

class TodayViewController: UIViewController, NCWidgetProviding {
    private let dateFormatter = DateFormatter()
    private let summary = GroupData()
    @IBOutlet weak var policeNearby: UILabel!
    @IBOutlet weak var lastUpdated: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.dateFormatter.locale = Locale(identifier: "en_US")
        self.dateFormatter.dateStyle = .short
        self.dateFormatter.timeStyle = .short
        // Do any additional setup after loading the view from its nib.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.
        
        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        DispatchQueue.main.async {
            self.policeNearby.text = "\(self.summary.policeNearby)"
            if let lastUpdated = self.summary.lastUpdated {
                self.lastUpdated.text = self.dateFormatter.string(for: lastUpdated)
            } else {
                self.lastUpdated.text = "???"
            }
            
        }
        completionHandler(NCUpdateResult.newData)
    }
    
}
