//
//  StatisticsViewController.swift
//  tvOSCopilot
//
//  Created by William Rory Kronmiller on 7/27/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreLocation
import Charts

class StatisticsViewController: DarkMapController, MKMapViewDelegate {
    private let labelQueue = DispatchQueue(label: "StatsLabelQueue")
    private let accelerationQueue = DispatchQueue(label: "StatsAccelerationLabelQueue")
    private let mapQueue = DispatchQueue(label: "StatsMapQueue")
    private let chartQueue = DispatchQueue(label: "StatsChartsQueue")
    
    @IBOutlet weak var lineChart: LineChartView!
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var vehicleLabel: UILabel!
    
    @IBOutlet weak var startDateLabel: UILabel!
    @IBOutlet weak var endDateLabel: UILabel!
    
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var altitudeLabel: UILabel!
    @IBOutlet weak var accelerationLabel: UILabel!
    @IBOutlet weak var pulseLabel: UILabel!
    
    private let formatter = DateFormatter()
    
    private var existingLine: MKGeodesicPolyline? = nil
    
    private func plotLocations(locationTrace: LocationTrace) {
        DispatchQueue.main.async {
            if let existingLine = self.existingLine {
                self.mapView.remove(existingLine)
            }
            self.existingLine = nil
        }
        self.mapQueue.async {
            if locationTrace.locations.isEmpty {
                return
            }
            let coordinates = locationTrace.locations.map{ location in
                return CLLocation(latitude: location.latitude, longitude: location.longitude)
            }
            
            let latitudes = locationTrace.locations.map{ location in return location.latitude }
            let longitudes = locationTrace.locations.map{ location in return location.longitude }
            
            let unsafeCoordinates = coordinates.map{ coordinate in return coordinate.coordinate }
            
            let polyline = MKGeodesicPolyline(coordinates: unsafeCoordinates, count: coordinates.count)
            
            let minLat = latitudes.min()!
            let maxLat = latitudes.max()!
            let minLon = longitudes.min()!
            let maxLon = longitudes.max()!
            
            let latitudeDelta = maxLat - minLat
            let longitudeDelta = maxLon - minLon
            let latitudeCenter = (maxLat + minLat) / 2
            let longitudeCenter = (maxLon + minLon) / 2
            let extraZoom = 0.01
            
            let span = MKCoordinateSpan(latitudeDelta: latitudeDelta + extraZoom, longitudeDelta: longitudeDelta + extraZoom)
            let center = CLLocationCoordinate2D(latitude: latitudeCenter, longitude: longitudeCenter)
            let region = MKCoordinateRegionMake(center, span)
            
            DispatchQueue.main.async {
                self.existingLine = polyline
                self.mapView.add(polyline)
                self.mapView.setRegion(region, animated: true)
            }
        }
    }
    
    private func showChart(rideStatistics: RideStatistics) {
        self.chartQueue.async {
            let pulseChartData = rideStatistics.biometrics.heartRateMeasurements.map{ pulseMeasurement in
                return ChartDataEntry(x: pulseMeasurement.start.timeIntervalSince1970, y: pulseMeasurement.value)
            }
            let pulseLine = LineChartDataSet(values: pulseChartData, label: "Pulse")
            pulseLine.colors = [
                .init(red: CGFloat(69.0 / 255), green: 0, blue: CGFloat(38.0 / 255), alpha: 1.0)
            ]
            pulseLine.circleRadius = 0
            pulseLine.lineWidth = 2.0
            
            let speedChartData = rideStatistics.locationTrace.locations.map{ location in
                return ChartDataEntry(x: location.epochMs / 1000, y: location.speed.metersPerSecondToMPH)
            }
            let speedLine = LineChartDataSet(values: speedChartData, label: "Speed")
            speedLine.colors = [
                .init(red: CGFloat(20.0 / 255), green: CGFloat(7.0 / 255), blue: CGFloat(58.0 / 255), alpha: 1.0)
            ]
            speedLine.circleRadius = 0
            speedLine.lineWidth = 2.0
            
            let accelerationChartData = rideStatistics.accelerationData.map{ acceleration in
                return ChartDataEntry(x: acceleration.epochMs / 1000, y: acceleration.magnitude)
            }
            let accelerationLine = LineChartDataSet(values: accelerationChartData, label: "Acceleration")
            accelerationLine.colors = [
                .init(red: CGFloat(38.0 / 255), green: CGFloat(3.0 / 255), blue: CGFloat(57.0 / 255), alpha: 0.5),
                .init(red: CGFloat(61.0 / 255), green: CGFloat(18.0 / 255), blue: CGFloat(85.0 / 255), alpha: 0.5)
            ]
            accelerationLine.circleRadius = 0
            accelerationLine.lineWidth = 1.0
            accelerationLine.axisDependency = .right
            
            let chartData = LineChartData(dataSets: [pulseLine, speedLine, accelerationLine])

            let chart = self.lineChart! //TODO: hide fullscreen cameras first
            DispatchQueue.main.async {
                chart.data = chartData
                chart.chartDescription?.text = "Speed - Acceleration - Pulse"
                chart.chartDescription?.font = UIFont(name: "Helvetica", size: 30)!
                chart.chartDescription?.textColor = UIColor.white
                chart.xAxis.drawLabelsEnabled = false
                chart.xAxis.gridColor = UIColor.white
                chart.rightAxis.drawLabelsEnabled = false
                chart.leftAxis.labelTextColor = UIColor.white
                chart.leftAxis.gridColor = UIColor.white
                chart.leftAxis.labelFont = UIFont(name: "Helvetica", size: 20)!
                chart.legend.enabled = false
                chart.tintColor = UIColor.clear
            }
        }
    }
    
    func updateLabels(stats: RideStatistics) {
        DispatchQueue.main.async {
            self.usernameLabel.text = stats.user.nickname
            self.vehicleLabel.text = stats.vehicle.model
            
            self.startDateLabel.text = self.formatter.string(for: stats.start)
            self.endDateLabel.text = self.formatter.string(for: stats.end)
        }
        self.labelQueue.async {
            NSLog("Calculating speed label")
            let speeds = stats.locationTrace.locations.map { location in return location.speed.metersPerSecondToMPH }
            if speeds.isEmpty {
                self.speedLabel.text = "Unknown"
            } else {
                let minSpeed = round(speeds.min()!)
                let maxSpeed = round(speeds.max()!)
                DispatchQueue.main.async {
                    self.speedLabel.text = "\(minSpeed)-\(maxSpeed)"
                }
            }
        }
        self.labelQueue.async {
            NSLog("Calculating altitude label")
            let altitudes = stats.locationTrace.locations.map { location in return location.altitude }
            if altitudes.isEmpty {
                self.altitudeLabel.text = "Unknown"
            } else {
                let minAltitude = round(altitudes.min()!)
                let maxAltitude = round(altitudes.max()!)
                DispatchQueue.main.async {
                    self.altitudeLabel.text = "\(minAltitude)-\(maxAltitude)"
                }
            }
        }
        
        self.labelQueue.async {
            NSLog("Calculating pulse label")
            let heartRates = stats.biometrics.heartRateMeasurements.map { pulse in return pulse.value }
            if heartRates.isEmpty {
                self.pulseLabel.text = "Unknown"
            } else {
                let minPulse = heartRates.min()!
                let maxPulse = heartRates.max()!
                DispatchQueue.main.async {
                    self.pulseLabel.text = "\(minPulse)-\(maxPulse)"
                }
            }
        }
        self.labelQueue.async {
            NSLog("Calculating acceleration label")
            let acceleration = stats.getRidingAcceleration(minMetersPerSecond: 20.0.metersPerSecondToMPH)
            NSLog("Got high-speed acelerations")
            let squaredMagnitudes = acceleration.map{ accel in return accel.squaredMagnitude }
            NSLog("Got acceleration squared magnitudes")
            if acceleration.isEmpty {
                self.accelerationLabel.text = "Unknown"
            } else {
                let minAcceleration = round(sqrt(squaredMagnitudes.min()!))
                let maxAcceleration = round(sqrt(squaredMagnitudes.max()!))
                DispatchQueue.main.async {
                    self.accelerationLabel.text = "\(minAcceleration)-\(maxAcceleration)"
                }
            }
        }
    }
    
    func refreshData(rideStatistics: RideStatistics) {
        self.plotLocations(locationTrace: rideStatistics.locationTrace)
        self.showChart(rideStatistics: rideStatistics)
        self.updateLabels(stats: rideStatistics)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.mapView.delegate = self
        self.mapView.add(baseMapOverlay, level: .aboveLabels)
        self.baseTileRenderer.reloadData()
        
        self.formatter.locale = Locale(identifier: "en_us")
        self.formatter.dateStyle = .short
        self.formatter.timeStyle = .short
        
        self.view.backgroundColor = UIColor(patternImage: UIImage(named: "panigale")!)
    }
    
    var loaded = false
    
    override func viewDidDisappear(_ animated: Bool) {
        NSLog("Unloaded statistics view")
        self.loaded = false
        super.viewDidDisappear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        NSLog("Loaded stats view")
        self.loaded = true
        super.viewDidAppear(animated)
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKTileOverlay {
            if overlay as! MKTileOverlay == self.baseMapOverlay {
                return baseTileRenderer
            }
        }
        
        if overlay is MKPolyline {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.strokeColor = UIColor.purple
            renderer.lineWidth = 6
            return renderer
        }
        
        return MKOverlayRenderer()
    }
}
