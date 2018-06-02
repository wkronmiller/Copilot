//
//  TrafficCamController.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 2/22/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import WebKit
import UIKit

class TrafficCamController: UIViewController, LocationTrackerDelegate, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var camTable: UITableView!
    
    private var camAddresses: [TrafficCam] = []
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        NSLog("Setting camaddrcount \(camAddresses.count)")
        return camAddresses.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = camTable.dequeueReusableCell(withIdentifier: "camera-cell", for: indexPath)
        let cam = self.camAddresses[indexPath.row]
        cell.textLabel?.text = cam.name
        cell.detailTextLabel?.text = cam.name
        NSLog("Setting cell \(cell)")
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        showCam(address: self.camAddresses[indexPath.row].address)
    }
    
    private func showCam(address: URL) {
        DispatchQueue.main.async {
            if (self.webView.url != address) {
                NSLog("CamController Setting web view to \(address)")
                self.webView.load(URLRequest(url: address))
            }
        }
    }
    
    private func showCam(index: Int) {
        showCam(address: self.camAddresses[index].address)
    }
    
    private func showCam() {
        if let address = camAddresses.first?.address {
            showCam(address: address)
        }
    }
    
    func didUpdateLocationStats(locationStats: LocationStats) {
        NSLog("CamController did update location stats \(locationStats)")
        self.camAddresses = locationStats.getCameras().getNearbyCameras()
        showCam()
        DispatchQueue.main.async {
            self.camTable.reloadData()
        }
    }
    
    override func  viewDidLoad() {
        self.camTable.delegate = self
        self.camTable.dataSource = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        NSLog("CamController did appear")
        LocationTracker.shared.setDelegate(delegate: self)
        showCam()
    }
    
}
