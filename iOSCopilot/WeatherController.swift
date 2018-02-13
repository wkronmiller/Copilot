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

struct ForecastPeriod {
    var startTime: Date
    var endTime: Date
    var temperature: Int
    var description: String
}

class WeatherTableCell: UITableViewCell {
    @IBOutlet weak var temperature: UILabel!
    @IBOutlet weak var conditions: UILabel!
    @IBOutlet weak var date: UILabel!
    
    func configure(forecastPeriod: ForecastPeriod) {
        self.temperature.text = String(forecastPeriod.temperature)
        self.conditions.text = forecastPeriod.description
        self.date.text = String(describing: forecastPeriod.startTime)
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

class WeatherInformation {
    private let endpoint = "https://api.weather.gov"
    private let dateFormatter = ISO8601DateFormatter()

    
    private func readDate(string: String) -> Date {
        return dateFormatter.date(from: string)!
    }
    
    private func unpackForecastPeriod(rawPeriod: [String: Any]) -> ForecastPeriod {
        let startTime = readDate(string: rawPeriod["startTime"] as! String)
        let endTime = readDate(string: rawPeriod["endTime"] as! String)
        
        let temperature = rawPeriod["temperature"] as! Int
        let description = rawPeriod["shortForecast"] as! String
        
        return ForecastPeriod(startTime: startTime, endTime: endTime, temperature: temperature, description: description)
    }
    private func unpackForecast(data: [String: Any]) -> [ForecastPeriod] {
        let properties = data["properties"] as! [String: Any]
        let periods = properties["periods"] as! [[String: Any]]
        return periods.map(unpackForecastPeriod).filter{forecastPeriod in
            return forecastPeriod.endTime.timeIntervalSinceNow > 0
        }
    }
    
    func getHourlyForecast(location: CLLocation, completionHandler: @escaping ([ForecastPeriod]?, Error?) -> Void) {
        let latitude = String(format: "%.4f", location.coordinate.latitude)
        let longitude = String(format: "%.4f", location.coordinate.longitude)
        let url = URL(string: "\(endpoint)/points/\(latitude),\(longitude)/forecast/hourly")!
        NSLog("Weather URL: \(url)") //TODO
        
        WebUplink.shared.get(url: url, completionHandler: {(data, error) in
            if nil != error {
                return completionHandler(nil, error)
            }
            let forecasts = self.unpackForecast(data: data!)
            return completionHandler(forecasts, nil)
        })
    }
}

class WeatherController: UIViewController, LocationTrackerDelegate {
    private let delegateConfig: LocationDelegateConfig
    private let weatherInformation = WeatherInformation()
    private let weatherTableDataSource = WeatherTableDataSource()

    @IBOutlet weak var weatherImage: UIImageView!
    @IBOutlet weak var weatherDescription: UILabel!
    @IBOutlet weak var currentTemperature: UILabel!
    
    @IBOutlet weak var weatherTable: UITableView!
    
    required init?(coder aDecoder: NSCoder) {
        self.delegateConfig = LocationDelegateConfig()
        super.init(coder: aDecoder)
        self.delegateConfig.delegate = self
        self.delegateConfig.maxUpdateFrequencyMs = 60 * 1000 // 1 minute
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.weatherTable.dataSource = self.weatherTableDataSource
    }

    private func descriptionToImage(description: String) -> String {
        switch description.replacingOccurrences(of: "Chance", with: "").trimmingCharacters(in: CharacterSet(charactersIn: " ")) {
        case "Mostly Sunny":
            return "weather-clear"
        case "Partly Cloudy":
            return "weather-few-clouds"
        case "Rain Showers":
            return "weather-showers-day"
        case "Clear":
            return "weather-clear"
        case "Sunny":
            return "weather-clear"
        default:
            break
        }
        //TODO: search for containment
        return "weather-none-available"
    }
    
    private func updateForecasts(forecasts: [ForecastPeriod]) {
        let current = forecasts.first!
        let nextImage = descriptionToImage(description: current.description)
        DispatchQueue.main.sync {
            self.weatherImage.image = UIImage(named: nextImage)!
            self.currentTemperature.text = "\(current.temperature) F"
            self.weatherDescription.text = current.description
        }
        
        DispatchQueue.main.sync {
            self.weatherTableDataSource.weatherData = Array(forecasts.prefix(20))
            self.weatherTable.reloadData()
        }
    }
    
    func didUpdateLocationStats(locationStats: LocationStats) {
        let location = locationStats.getLastLocation()
        weatherInformation.getHourlyForecast(location: location, completionHandler: {(forecasts, error) in
            if nil != error {
                NSLog("Error fetching forecast \(error!)")
                return
            }
            self.updateForecasts(forecasts: forecasts!)
        })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        LocationTracker.shared.setDelegate(delegateConfig: self.delegateConfig)
    }
    //TODO
}
