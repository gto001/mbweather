//
//  Weather.swift
//  mbweather
//

import Foundation

struct Weather {
    var date: String // YYYY-MM-DD
    var weatherCode: Int64
    var temperatureMin: Double
    var temperatureMax: Double
    var apparentTemperatureMin: Double
    var apparentTemperatureMax: Double
    
    init(date: String,
         weatherCode: Int64,
         temperatureMin: Double,
         temperatureMax: Double,
         apparentTemperatureMin: Double,
         apparentTemperatureMax: Double) {
        self.date = date
        self.weatherCode = weatherCode
        self.temperatureMin = temperatureMin
        self.temperatureMax = temperatureMax
        self.apparentTemperatureMin = apparentTemperatureMin
        self.apparentTemperatureMax = apparentTemperatureMax
    }
}
