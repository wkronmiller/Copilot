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
    @IBOutlet weak var accelerationLabel: UILabel!
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var pulseLabel: UILabel!
    
    @IBOutlet weak var startDate: UIDatePicker!
    @IBOutlet weak var endDate: UIDatePicker!
    @IBOutlet weak var connectionTable: UITableView!
    @IBOutlet weak var sendLocationsButton: UIButton!
    
    private let meshNetwork = MeshNetworkController()
    
    private var selectedConnection: MeshConnection? = nil

    private func resetDates() {
        DispatchQueue.main.async {
            self.startDate.date = Date().addingTimeInterval(-60 * 60 * 5)
            self.endDate.date = Date()
        }
    }

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
        self.resetDates()
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
    
    //TODO: move this method into something else
    private func getRideStatistics(startDate: Date, endDate: Date, completionHandler: @escaping (RideStatistics) -> Void) {
        if startDate >= endDate {
            NSLog("Dates invalid")
            return
        }
        let dateInterval = DateInterval(start: startDate, end: endDate)
        let locationSegments = LocationTrace(locations: LocationDatabase.shared.getLocations(dateInterval: dateInterval))
        let accelerationData: [Acceleration] = LocationDatabase.shared.getAccelerometerData(dateInterval: dateInterval)
        BiometricTracker.shared.getHeartRates(start: dateInterval.start, end: dateInterval.end, maxPoints: 1000, completionHandler: { error, measurements in
            if error != nil {
                return
            }
            let biometricSummary = BiometricSummary(heartRateMeasurements: measurements)
            let rideStatistics = RideStatistics(start: self.startDate.date, end: self.endDate.date, biometrics: biometricSummary, locationTrace: locationSegments, accelerationData: accelerationData)
            NSLog("Sending ride statistics \(rideStatistics)")
            
            completionHandler(rideStatistics)
        })
    }
    
    private var refreshing = false
    func refreshStatsView() {
        if refreshing {
            return
        }
        self.refreshing = true
        getRideStatistics(startDate: self.startDate.date, endDate: self.endDate.date){ rideStatistics in
            //TODO
            self.refreshing = false
        }
    }
    
    @IBAction func sendLocationsClicked(_ sender: Any) {
        self.getRideStatistics(startDate: self.startDate.date, endDate: self.endDate.date) { rideStatistics in
            self.meshNetwork.sendRideSummary(connection: self.selectedConnection!, rideStatistics: rideStatistics)
        }
    }
    
    @IBAction func startDateChanged(_ sender: UIDatePicker) {
        DispatchQueue.main.async {
            self.endDate.minimumDate = self.startDate.date
        }
        self.refreshStatsView()
    }
    @IBAction func endDateChanged(_ sender: UIDatePicker) {
        DispatchQueue.main.async {
            self.startDate.maximumDate = self.endDate.date
        }
        self.refreshStatsView()
    }

}
