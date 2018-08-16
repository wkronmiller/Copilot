//
//  BiometricTracker.swift
//  iOSCopilot
//
//  Created by William Rory Kronmiller on 7/20/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import HealthKit

class BiometricTracker: NSObject {
    private var authorized = false
    private let hkHealthStore = HKHealthStore()
    private let heartRateUnit = HKUnit(from: "count/min")
    
    private let dataToRead = Set([
        HKObjectType.quantityType(forIdentifier: .heartRate)!
    ])
    
    func authorize() {
        self.hkHealthStore.requestAuthorization(toShare: Set(), read: dataToRead, completion: {authorized, error in
            if(error != nil || authorized == false) {
                NSLog("Failed to authorize healthkit \(error)")
                return
            }
            self.authorized = true
        })
    }
    
    func getHeartRates(start: Date, end: Date, maxPoints: Int, completionHandler: @escaping (Error?, [HeartRateMeasurement]) -> Void) {
        let sampleType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: maxPoints, sortDescriptors: [sortDescriptor]){ (sampleQuery, results, error) in
            if error != nil {
                NSLog("Failed to get healthkit results \(error) from query \(sampleQuery)")
                completionHandler(error, [])
                return
            }
            let measurements = results!.map{ result -> HeartRateMeasurement in
                let value = (result as! HKQuantitySample).quantity.doubleValue(for: self.heartRateUnit)
                return HeartRateMeasurement(start: result.startDate, end: result.endDate, value: value)
            }
            completionHandler(nil, measurements)
            return
        }
        self.hkHealthStore.execute(query)
    }
    
    static let shared = BiometricTracker()
}
