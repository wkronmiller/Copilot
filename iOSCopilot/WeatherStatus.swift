//
//  WeatherStatus.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 2/14/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import CoreLocation

public struct ForecastPeriod {
    var startTime: Date
    var endTime: Date
    var temperature: Int
    var description: String
}

public class WeatherStatus: NSObject {
    private let receiverConfig: LocationReceiverConfig
    private let endpoint = "https://api.weather.gov"
    private let dateFormatter = ISO8601DateFormatter()
    
    private var forecasts: [ForecastPeriod] = []
    
    override init() {
        self.receiverConfig = LocationReceiverConfig()
        self.receiverConfig.maxUpdateFrequencyMs = 10 * 60 * 1000 // 10 minutes
        super.init()
    }
    
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
        if let properties = data["properties"] as? [String: Any] {
            if let periods = properties["periods"] as? [[String: Any]] {
                return periods.map(unpackForecastPeriod).filter{forecastPeriod in
                    return forecastPeriod.endTime.timeIntervalSinceNow > 0
                }
            }
        }
        NSLog("Weather forecast corrupted: \(data)")
        return []
    }

    func getForecasts() -> [ForecastPeriod] {
        return self.forecasts.filter{forecast in
            return forecast.endTime.timeIntervalSinceNow > 0
        }
    }
    
    func getHourlyForecast(location: CLLocation, completionHandler: @escaping ([ForecastPeriod]?, Error?) -> Void) {
        let latitude = String(format: "%.4f", location.coordinate.latitude)
        let longitude = String(format: "%.4f", location.coordinate.longitude)
        let url = URL(string: "\(endpoint)/points/\(latitude),\(longitude)/forecast/hourly")!
        
        if self.receiverConfig.shouldUpdate() {
            WebUplink.shared.get(url: url, completionHandler: {(data, error) in
                if nil != error {
                    return completionHandler(nil, error)
                }
                self.forecasts = self.unpackForecast(data: data!)
                self.receiverConfig.didUpdate()
                return completionHandler(self.getForecasts(), nil)
            })
        } else {
            return completionHandler(self.forecasts, nil)
        }
    }
    
    func getTimeToBadWeather() -> TimeInterval? {
        let inclementForecasts = getForecasts()
            .filter{ forecast in
                let description = forecast.description.lowercased()
                return description.contains("rain") || description.contains("snow") || description.contains("storm")
            }
            .map{forecast in
                forecast.startTime
            }
        return inclementForecasts.first.map{startTime in
            startTime.timeIntervalSinceNow
        }
    }
}
