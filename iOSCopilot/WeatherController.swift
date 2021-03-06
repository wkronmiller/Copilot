//
//  WeatherController.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 2/12/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation

class WeatherTableCell: UITableViewCell {
    @IBOutlet weak var temperature: UILabel!
    @IBOutlet weak var conditions: UILabel!
    @IBOutlet weak var date: UILabel!
    
    func configure(forecastPeriod: ForecastPeriod) {
        self.temperature.text = String(forecastPeriod.temperature)
        self.conditions.text = forecastPeriod.description
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        self.date.text = dateFormatter.string(from: forecastPeriod.startTime)
    }

}

class WeatherTableDataSource: NSObject, UITableViewDataSource {
    var weatherData: [ForecastPeriod] = []
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return weatherData.count
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "weatherCell", for: indexPath) as! WeatherTableCell
        
        cell.configure(forecastPeriod: weatherData[indexPath.row])
        
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
}

class WeatherController: UIViewController, LocationTrackerDelegate {
    private let delegateConfig: LocationReceiverConfig
    private let weatherTableDataSource = WeatherTableDataSource()

    @IBOutlet weak var weatherImage: UIImageView!
    @IBOutlet weak var weatherDescription: UILabel!
    @IBOutlet weak var currentTemperature: UILabel!
    @IBOutlet weak var ridingTimeRemaining: UILabel!
    
    @IBOutlet weak var weatherTable: UITableView!
    
    required init?(coder aDecoder: NSCoder) {
        self.delegateConfig = LocationReceiverConfig()
        super.init(coder: aDecoder)
        self.delegateConfig.delegate = self
        self.delegateConfig.maxUpdateFrequencyMs = 60 * 1 // 1 minute
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.weatherTable.dataSource = self.weatherTableDataSource
    }

    private func descriptionToImage(description: String) -> String {
        let lowercased = description.lowercased()
        if(lowercased.contains("storm")) {
            return "weather-storm"
        }
        if(lowercased.contains("rain")) {
            return "weather-rain-day"
        }
        if(lowercased.contains("shower")) {
            return "weather-showers-day"
        }
        if(lowercased.contains("snow")) {
            return "weather-snow"
        }
        if(lowercased.contains("cloud")) {
            return "weather-few-clouds"
        }
        if(lowercased.contains("clear") || lowercased.contains("sun")) {
            return "weather-clear"
        }
        
        return "weather-none-available"
    }
    
    private func updateForecasts(weatherStatus: WeatherStatus) {
        let forecasts = weatherStatus.getForecasts()
        if let current = forecasts.first {
            let nextImage = descriptionToImage(description: current.description)
            DispatchQueue.main.async {
                self.weatherImage.image = UIImage(named: nextImage)!
                self.currentTemperature.text = "\(current.temperature) F"
                self.weatherDescription.text = current.description
            }
        }
        
        DispatchQueue.main.async {
            self.weatherTableDataSource.weatherData = Array(forecasts.prefix(20))
            self.weatherTable.reloadData()
        }
        
        if let secondsRemaining = weatherStatus.getTimeToBadWeather() {
            let hoursRemaining = String(format: "%.1f", secondsRemaining / (60 * 60))
            DispatchQueue.main.async {
                self.ridingTimeRemaining.text = "\(hoursRemaining) hours good weather"
            }
        } else {
            DispatchQueue.main.async {
                self.ridingTimeRemaining.text = nil
            }
        }
    }
    
    func didUpdateLocationStats(locationStats: LocationStats) {
        self.updateForecasts(weatherStatus: locationStats.getWeatherStatus())
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppDelegate.locationTracker!.setDelegate(delegateConfig: self.delegateConfig)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        AppDelegate.locationTracker!.clearDelegate()
    }

}
