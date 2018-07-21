//
//  NetworkingViewController.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 7/7/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import MultipeerConnectivity
import UIKit

class MeshConnectionTableCell: UITableViewCell {
    @IBOutlet weak var connectionName: UILabel!
}

class NetworkingViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, MeshControllerDelegate {
    @IBOutlet weak var startDate: UIDatePicker!
    @IBOutlet weak var endDate: UIDatePicker!
    @IBOutlet weak var connectionTable: UITableView!
    @IBOutlet weak var sendLocationsButton: UIButton!
    
    private let meshNetwork = MeshNetworkController()
    
    private var selectedConnection: MeshConnection? = nil
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.meshNetwork.startAdvertising()
        self.meshNetwork.delegate = self
        self.connectionTable.delegate = self
        self.connectionTable.dataSource = self
        if self.selectedConnection == nil {
            self.sendLocationsButton.isEnabled = false
        }
        NSLog("Advertising mesh")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.meshNetwork.stopAdvertising()
        NSLog("Not advertising mesh")
    }
    
    func connection(_ network: MeshNetwork, didConnect connection: MeshConnection) {
        NSLog("Got new mesh connection \(connection.peerID.displayName)")
        DispatchQueue.main.async {
            self.connectionTable.reloadData()
        }
    }
    
    func connection(_ network: MeshNetwork, didDisconnect peerID: MCPeerID) {
        if let selectedConnection = self.selectedConnection {
            if peerID == selectedConnection.peerID {
                self.selectedConnection = nil
            }
        }
        DispatchQueue.main.async {
            self.connectionTable.reloadData()
        }
    }
    
    func connection(_ network: MeshNetwork, gotLocations: [LocationSegment], connection: MeshConnection) {}
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if(section == 0) {
            return meshNetwork.getConnected().count
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "connectionCell", for: indexPath) as! MeshConnectionTableCell
        cell.connectionName.text = meshNetwork.getConnected()[indexPath.row].peerID.displayName
        NSLog("Created mesh cell for path \(indexPath)")
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.selectedConnection = self.meshNetwork.getConnected()[indexPath.row]
        NSLog("Selected connection \(self.selectedConnection)")
        self.sendLocationsButton.isEnabled = true
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        self.selectedConnection = nil
        self.sendLocationsButton.isEnabled = false
    }
    
    @IBAction func sendLocationsClicked(_ sender: Any) {
        if startDate.date >= endDate.date {
            NSLog("Dates invalid")
            return
        }
        let dateInterval = DateInterval(start: startDate.date, end: endDate.date)
        self.meshNetwork.sendLocations(connection: self.selectedConnection!, dateInterval: dateInterval)
        //TODO: summarize biometrics and correlate with speeds
        NSLog("Preparing biometric data")
        BiometricTracker.shared.getHeartRates(start: dateInterval.start, end: dateInterval.end, maxPoints: 1000, completionHandler: { error, measurements in
            if error != nil {
                return
            }
            NSLog("Sending biometric data")
            let biometricSummary = BiometricSummary(heartRateMeasurements: measurements)
            self.meshNetwork.sendBiometrics(connection: self.selectedConnection!, biometricSummary: biometricSummary)
        })
        
        let accelerationData: [Acceleration] = LocationDatabase.shared.getAccelerometerData(dateInterval: dateInterval)
        self.meshNetwork.sendAcceleration(connection: self.selectedConnection!, accelerationData: accelerationData)
    }

}
