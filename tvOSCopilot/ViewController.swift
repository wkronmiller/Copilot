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
class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, MeshConnectionDelegate {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var playerContainer: UIView!
    
    @IBOutlet weak var meshStatusView: UIView!
    @IBOutlet weak var meshStatusText: UILabel!
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
    
    private let meshNetwork = MeshNetwork(isBaseStation: true)
    
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
    
    private func openConnection(network: MeshNetwork, connection: MeshConnection) {
        self.meshConnection = connection
        
        network.requestLocations(connection: connection)
        DispatchQueue.main.async {
            self.meshStatusView.isHidden = false
            self.meshStatusText.text = "Apple Mesh Connected"
        }
    }
    
    func connection(_ network: MeshNetwork, didConnect connection: MeshConnection) {
        NSLog("Connected to peer \(connection.peerID)")
        if connection.peerUUID == self.meshConnection?.peerUUID {
            self.openConnection(network: network, connection: connection)
            return
        }
        let alert = UIAlertController(title: "Copilot Device Detected", message: "Apple Mesh connected to device \(connection.peerUUID)", preferredStyle: .alert)
        let dismissAction = UIAlertAction(title: "Dismiss", style: .cancel, handler: nil)
        alert.addAction(dismissAction)
        let displayTracesAction = UIAlertAction(title: "Load Data", style: .default, handler: {action in
            self.openConnection(network: network, connection: connection)
        })
        alert.addAction(displayTracesAction)
        self.present(alert, animated: true, completion: nil)
        NSLog("Sent alert")
    }
    
    func connection(_ network: MeshNetwork, didDisconnect peerID: MCPeerID) {
        NSLog("Disconnected from peer \(peerID)")
        if peerID == self.meshConnection?.peerID {
            DispatchQueue.main.async {
                self.meshStatusView.isHidden = true
                //TODO: remove polyline annotations
            }
        }
    }
    
    func connection(_ network: MeshNetwork, gotLocations: [LocationSegment], connection: MeshConnection) {
        NSLog("Got locations \(gotLocations)")
        let coordinates = gotLocations.map{ location in
            return CLLocation(latitude: location.latitude, longitude: location.longitude)
        }
        let unsafeCoordinates = coordinates.map{ coordinate in return coordinate.coordinate }
        let topSpeed = gotLocations.map{ location in return location.speed }.max()!
        let newPolyline = MKGeodesicPolyline(coordinates: unsafeCoordinates, count: coordinates.count)
        DispatchQueue.main.async {
            if let existingLine = self.trackedDeviceTrace {
                self.mapView.remove(existingLine)
            }
            if newPolyline.pointCount > 0 {
                self.mapView.add(newPolyline)
                self.trackedDeviceTrace = newPolyline
            }
            self.meshStatusText.text = "Top Speed \(round(topSpeed * 10) / 10) MPH"
            
            if let lastLoc = coordinates.last {
                let region = MKCoordinateRegionMakeWithDistance(lastLoc.coordinate, 10000, 10000)
                self.mapView.setRegion(region, animated: true)
            }
        }
        
        //TODO: option to clear view
    }
    
    
}

