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
import AVKit
import AVFoundation

class TrafficCamController: UIViewController, LocationTrackerDelegate, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var autoToggle: UISwitch!
    
    @IBOutlet weak var camTable: UITableView!
    
    @IBOutlet weak var playerContainer: UIView!
    
    private var camAddresses: [TrafficCam] = []
    
    private var playing: URL? = nil
    
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
        if(address == self.playing) {
            return
        }
        self.playing = address
        
        let player = AVPlayer(url: address)
        let playerLayer = AVPlayerLayer(player: player)
        DispatchQueue.main.async {
            // Clear existing sublayers
            self.playerContainer.layer.sublayers?.forEach{ $0.removeFromSuperlayer() }
            playerLayer.frame = self.playerContainer.bounds
            self.playerContainer.layer.addSublayer(playerLayer)
            player.play()
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
        if(self.autoToggle.isOn) {
            showCam()
        }
        DispatchQueue.main.async {
            self.camTable.reloadData()
        }
    }
    
    override func viewDidLoad() {
        NSLog("CamController did load")
        self.camTable.delegate = self
        self.camTable.dataSource = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        NSLog("CamController did appear")
        LocationTracker.shared.setDelegate(delegate: self)
        showCam()
    }
    
}
