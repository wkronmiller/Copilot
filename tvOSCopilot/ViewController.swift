//
//  ViewController.swift
//  tvOSCopilot
//
//  Created by William Rory Kronmiller on 7/6/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import AVKit
import MultipeerConnectivity
import Charts

class TrafficCamAnnotation: NSObject, MKAnnotation {
    var address: URL
    var title: String?
    var coordinate: CLLocationCoordinate2D
    
    init(trafficCam: TrafficCam) {
        self.address = trafficCam.address
        self.title = trafficCam.name
        self.coordinate = trafficCam.location.coordinate
    }
}

//TODO: annotation clustering
class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, MeshBaseStationDelegate {
    
    
    private let metersToMph = 2.23694 // Meters/second to MPH
    
    @IBOutlet weak var speedChart: LineChartView!
    @IBOutlet weak var pulseChart: LineChartView!
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var playerContainer: UIView!
    
    @IBOutlet weak var meshStatusView: UIView!
    @IBOutlet weak var meshStatusText: UILabel!
    @IBOutlet weak var accelerationText: UILabel!
    @IBOutlet weak var heartRateText: UILabel!
    @IBOutlet weak var altitudeRangeText: UILabel!
    private var meshConnection: MeshConnection? = nil
    private var trackedDeviceTrace: MKPolyline? = nil
    
    private let locationManager = CLLocationManager()
    
    private let trafficCams = TrafficCams()
    private var showingCameras: Bool = false
    private var trafficCamAnnotations: [TrafficCamAnnotation] = []
    
    private let baseMapOverlay: MKTileOverlay
    private let baseTileRenderer: MKTileOverlayRenderer
    private let radarMapOverlay: MKTileOverlay
    private let radarTileRenderer: MKTileOverlayRenderer
    private var radarLastRefreshed: Date? = nil
    
    private let meshNetwork = MeshBaseStation()
    
    required init?(coder aDecoder: NSCoder) {
        self.baseMapOverlay = MKTileOverlay(urlTemplate: Configuration.shared.baseMapTileUrl)
        self.baseTileRenderer = MKTileOverlayRenderer(tileOverlay: self.baseMapOverlay)
        baseMapOverlay.canReplaceMapContent = true
        
        self.radarMapOverlay = MKTileOverlay(urlTemplate: Configuration.shared.radarTileUrl)
        
        self.radarTileRenderer = MKTileOverlayRenderer(tileOverlay: self.radarMapOverlay)
        super.init(coder: aDecoder)
        
        locationManager.delegate = self
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.requestWhenInUseAuthorization()
        mapView.delegate = self
        
        mapView.add(baseMapOverlay, level: .aboveLabels)
        mapView.add(radarMapOverlay, level: .aboveLabels)
        mapView.showsUserLocation = true
        mapView.showsScale = false

        
        baseTileRenderer.reloadData()
        radarTileRenderer.reloadData()
        radarLastRefreshed = Date()
        
        trafficCams.refresh(allCamerasLoaded: {error in
            if error != nil {
                NSLog("Error getting all traffic cameras \(error!)")
                return
            }

            self.trafficCamAnnotations = self.trafficCams.getCameras().map({cam in
                return TrafficCamAnnotation(trafficCam: cam)
            })
        })
        meshNetwork.delegate = self
        meshNetwork.startAdvertising()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKTileOverlay {
            if overlay as! MKTileOverlay == self.baseMapOverlay {
                return baseTileRenderer
            }
            
            return radarTileRenderer
        }

        if overlay is MKPolyline {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.strokeColor = UIColor.purple
            renderer.lineWidth = 6
            return renderer
        }

        return MKOverlayRenderer()
    }
    
    private func scaleImage(scale: Int, image: UIImage) -> UIImage {
        let size = CGSize(width: scale, height: scale)
        UIGraphicsBeginImageContext(size)
        image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resizedImage
    }
    
    private func ensureView(withIdentifier: String, annotation: MKAnnotation?) -> MKAnnotationView {
        let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: withIdentifier)
        if annotationView == nil {
            return MKAnnotationView(annotation: annotation, reuseIdentifier: withIdentifier)
        }
        return annotationView!
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        self.maybeShowCameras()
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        NSLog("Handling annotation \(annotation)")
        if annotation is MKUserLocation {
            NSLog("User location annotation")
            let annotationView = ensureView(withIdentifier: "userLocation", annotation: annotation)
            NSLog("Ensured annotation view \(annotationView)")
            annotationView.isEnabled = true
            let pinImage = UIImage(named: "crosshairs")!
            annotationView.image = scaleImage(scale: 50, image: pinImage)
            return annotationView
        }
        
        if annotation is TrafficCamAnnotation {
            let annotationView = ensureView(withIdentifier: "trafficCameras", annotation: annotation)
            annotationView.image = scaleImage(scale: 30, image: UIImage(named: "camera")!)
            annotationView.isEnabled = true
            annotationView.canShowCallout = true
            return annotationView
            
        }
        return nil
    }
    
    private var playing: URL? = nil
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        NSLog("Selected view \(view)")
        if view.annotation is TrafficCamAnnotation {
            let trafficAnnotation = view.annotation as! TrafficCamAnnotation
            self.playing = trafficAnnotation.address
            let player = AVPlayer(url: trafficAnnotation.address)
            player.isMuted = true
            let playerLayer = AVPlayerLayer(player: player)
            DispatchQueue.main.async {
                self.playerContainer.layer.sublayers?.forEach{ $0.removeFromSuperlayer() }
                playerLayer.frame = self.playerContainer.bounds
                self.playerContainer.layer.addSublayer(playerLayer)
                player.play()
            }
        }
        if view.annotation is MKUserLocation {
            self.playing = nil
            DispatchQueue.main.async {
                self.playerContainer.layer.sublayers?.forEach{ $0.removeFromSuperlayer() }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        NSLog("Got locations \(locations)")
        if let lastLoc = locations.last {
            let region = MKCoordinateRegionMakeWithDistance(lastLoc.coordinate, 1000, 1000)
            mapView.setRegion(region, animated: false)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NSLog("Failed to get locations \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch(status) {
        case .denied:
            NSLog("Denied location permissions")
            break
        case .notDetermined:
            NSLog("Location status not determined")
            break
        case .authorizedWhenInUse:
            NSLog("Authorized to use location")
            self.locationManager.requestLocation()
            break
        default:
            NSLog("Location status changed \(status.rawValue)")
        }
    }
    
    @IBAction func longPressed(_ sender: Any) {
        if let url = self.playing {
            let playerController = AVPlayerViewController()
            playerController.modalPresentationStyle = .fullScreen
            let player = AVPlayer(url: url)
            playerController.player = player
            player.play()
            DispatchQueue.main.async {
                self.present(playerController, animated: true, completion: {
                    NSLog("Went fullscreen")
                })
            }
            return
        }
        DispatchQueue.main.async {
            var doRefresh = true
            if let lastReloaded = self.radarLastRefreshed {
                doRefresh = (abs(lastReloaded.timeIntervalSinceNow) > 5)
            }
            if doRefresh {
                self.radarLastRefreshed = Date()
                NSLog("Refreshing radar data")
                self.radarTileRenderer.reloadData()
            }
        }
    }
    
    func maybeShowCameras() {
        let maxZoom = 0.4
        let zoomLevel = self.mapView!.region.span.latitudeDelta
        NSLog("Zoom level \(zoomLevel)")
        if zoomLevel > maxZoom && showingCameras {
            self.showingCameras = false
            self.mapView.removeAnnotations(self.trafficCamAnnotations)
            NSLog("Hiding cameras")
        }
        if zoomLevel < maxZoom && !showingCameras && self.trafficCamAnnotations.count > 0 {
            self.showingCameras = true
            self.mapView.addAnnotations(self.trafficCamAnnotations)
            NSLog("Showing cameras")
        }
    }
    
    private func openConnection(network: MeshNetwork, connection: MeshConnection) {}
    
    func connection(_ network: MeshNetwork, didConnect connection: MeshConnection) {}
    
    private func clearPolylines() {
        if let existingLine = self.trackedDeviceTrace {
            self.mapView.remove(existingLine)
        }
    }
    
    func connection(_ network: MeshNetwork, didDisconnect peerID: MCPeerID) {
        NSLog("Disconnected from peer \(peerID)")
        if peerID == self.meshConnection?.peerID {
            DispatchQueue.main.async {
                self.meshStatusView.isHidden = true
                self.speedChart.isHidden = true
                self.pulseChart.isHidden = true
                self.meshStatusText.text = "Mesh Connected"
                self.altitudeRangeText.text = "Altitude Unknown"
                self.accelerationText.text = "Acceleration Unknown"
                self.heartRateText.text = "Heart Rate Unknown"
                self.clearPolylines()
            }
        }
    }
    
    private func prepareChart(description: String, lineChartData: [ChartDataEntry], chart: LineChartView!) {
        let line = LineChartDataSet(values: lineChartData, label: description)
        line.circleRadius = 0.1
        
        line.lineWidth = 3.0
        line.colors = [UIColor.purple]
        line.valueTextColor = UIColor.clear

        let data = LineChartData(dataSets: [line])
        
        DispatchQueue.main.async {
            self.playerContainer.isHidden = true
            chart.clear()
            
            chart.data = data
            chart.chartDescription?.text = description
            chart.chartDescription?.font = UIFont(name: "Helvetica", size: 30)!
            chart.chartDescription?.textColor = UIColor.white
            chart.xAxis.drawLabelsEnabled = false
            chart.xAxis.gridColor = UIColor.white
            chart.rightAxis.drawLabelsEnabled = false
            chart.leftAxis.labelTextColor = UIColor.white
            chart.leftAxis.gridColor = UIColor.white
            chart.leftAxis.labelFont = UIFont(name: "Helvetica", size: 20)!
            chart.legend.enabled = false
            chart.alpha = 0.8
            chart.backgroundColor = UIColor.darkGray
            chart.isHidden = false
        }
    }
    
    private func chartSpeeds(locationSegments: [LocationSegment]) {
        let lineChartData: [ChartDataEntry] = locationSegments.map{ segment in
            return ChartDataEntry(x: segment.epochMs, y: segment.speed * metersToMph)
        }

        self.prepareChart(description: "Speed", lineChartData: lineChartData, chart: self.speedChart)
    }
    
    private func chartPulse(heartRates: [HeartRateMeasurement]) {
        let lineChartData = heartRates.map{ segment in
            return ChartDataEntry(x: segment.end.timeIntervalSince1970, y: segment.value)
        }
        
        self.prepareChart(description: "Pulse", lineChartData: lineChartData, chart: self.pulseChart)
    }
    
    func connection(_ network: MeshNetwork, gotLocations: [LocationSegment], connection: MeshConnection) {
        self.meshConnection = connection
        NSLog("TV view got locations \(gotLocations)")
        if gotLocations.isEmpty {
            NSLog("Got no locations")
            return
        }
        let coordinates = gotLocations.map{ location in
            return CLLocation(latitude: location.latitude, longitude: location.longitude)
        }
        
        let latitudes = gotLocations.map{ location in return location.latitude }
        let longitudes = gotLocations.map{ location in return location.longitude }
        
        let unsafeCoordinates = coordinates.map{ coordinate in return coordinate.coordinate }
        let topSpeedMPH = gotLocations.map{ location in return location.speed }.max()! * metersToMph
        let altitudes = gotLocations.map{ location in return location.altitude }
        let minAltitude = altitudes.min()!
        let maxAltitude = altitudes.max()!
        //TODO: peak acceleration
        let newPolyline = MKGeodesicPolyline(coordinates: unsafeCoordinates, count: coordinates.count)
        NSLog("Will display client locations")
        
        let minLat = latitudes.min()!
        let maxLat = latitudes.max()!
        let minLon = longitudes.min()!
        let maxLon = longitudes.max()!
        
        let latitudeDelta = maxLat - minLat
        let longitudeDelta = maxLon - minLon
        let latitudeCenter = (maxLat + minLat) / 2
        let longitudeCenter = (maxLon + minLon) / 2
        let extraZoom = 0.5
        
        let span = MKCoordinateSpan(latitudeDelta: latitudeDelta + extraZoom, longitudeDelta: longitudeDelta + extraZoom)
        let center = CLLocationCoordinate2D(latitude: latitudeCenter, longitude: longitudeCenter)
        let region = MKCoordinateRegionMake(center, span)
        
        DispatchQueue.main.async {
            NSLog("Displaying client locations")
            self.clearPolylines()
            self.meshStatusView.isHidden = false
            if newPolyline.pointCount > 0 {
                self.mapView.add(newPolyline)
                self.trackedDeviceTrace = newPolyline
            }
            self.meshStatusText.text = "Top Speed \(round(topSpeedMPH  * 10) / 10) MPH"
            self.altitudeRangeText.text = "Altitude \(round(minAltitude)) - \(round(maxAltitude))m"
            self.mapView.setRegion(region, animated: true)
            
        }
        
        self.chartSpeeds(locationSegments: gotLocations)
    }
    
    func connection(_ network: MeshNetwork, gotBiometrics: BiometricSummary, connection: MeshConnection) {
        NSLog("Got biometric data \(gotBiometrics)")
        let pulses = gotBiometrics.heartRateMeasurements.map{ measurement in return measurement.value }
        let minPulse = pulses.min()
        let maxPulse = pulses.max()
        if pulses.isEmpty == false {
            DispatchQueue.main.async {
                self.heartRateText.text = "Heart Rate \(minPulse!) - \(maxPulse!)"
            }
        }
        self.chartPulse(heartRates: gotBiometrics.heartRateMeasurements)
    }

    func connection(_ network: MeshNetwork, gotAcceleration: [Acceleration], connection: MeshConnection) {
        NSLog("Got acceleration \(gotAcceleration)")
        let cumAcceleration = gotAcceleration.map{ accel in return abs(accel.x) + abs(accel.y) + abs(accel.z) }
        if let peakAcceleration = cumAcceleration.max() {
            DispatchQueue.main.async {
                self.accelerationText.text = "Max Acceleration \(round(peakAcceleration))g"
            }
        }
    }
    
}

