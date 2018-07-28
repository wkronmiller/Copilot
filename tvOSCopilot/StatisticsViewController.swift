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
    private let metersToMph = 2.23694 // Meters/second to MPH
    
    private var existingLine: MKGeodesicPolyline? = nil
    
    private func chartLocations(locationTrace: LocationTrace) {
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
            if let existingLine = self.existingLine {
                self.mapView.remove(existingLine)
            }
            self.existingLine = polyline
            self.mapView.add(polyline)
            self.mapView.setRegion(region, animated: true)
        }
    }
    
    private func showChart(rideStatistics: RideStatistics) {
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
            return ChartDataEntry(x: location.epochMs / 1000, y: location.speed * metersToMph)
        }
        let speedLine = LineChartDataSet(values: speedChartData, label: "Speed")
        speedLine.colors = [
            .init(red: CGFloat(20.0 / 255), green: CGFloat(7.0 / 255), blue: CGFloat(58.0 / 255), alpha: 1.0)
        ]
        speedLine.circleRadius = 0
        speedLine.lineWidth = 2.0
        
        let accelerationChartData = rideStatistics.accelerationData.map{ acceleration in
            return ChartDataEntry(x: acceleration.epochMs / 1000, y: acceleration.getMagnitude())
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

        let chart = self.lineChart!
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
            chart.backgroundColor = UIColor.darkGray
            chart.tintColor = UIColor.clear
        }
    }
    
    func updateLabels(stats: RideStatistics) {
        self.usernameLabel.text = stats.user.nickname
        self.vehicleLabel.text = stats.vehicle.model
        
        self.startDateLabel.text = self.formatter.string(for: stats.start)
        self.endDateLabel.text = self.formatter.string(for: stats.end)
        
        let speeds = stats.locationTrace.locations.map { location in return location.speed * self.metersToMph }
        self.speedLabel.text = "\(round(speeds.min()!))-\(round(speeds.max()!))"
        
        let altitudes = stats.locationTrace.locations.map { location in return location.altitude }
        self.altitudeLabel.text = "\(round(altitudes.min()!))-\(round(altitudes.max()!))"
        
        let acceleration = stats.accelerationData.map{ accel in return accel.getMagnitude() }
        self.accelerationLabel.text = "\(round(acceleration.min()!))-\(round(acceleration.max()!))"
        
        let heartRates = stats.biometrics.heartRateMeasurements.map { pulse in return pulse.value }
        self.pulseLabel.text = "\(heartRates.min()!)-\(heartRates.max()!)"
    }
    
    func refreshData(rideStatistics: RideStatistics) {
        self.chartLocations(locationTrace: rideStatistics.locationTrace)
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
