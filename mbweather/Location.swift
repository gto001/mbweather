//
//  Location.swift
//  mbweather
//

import Foundation

struct Location : Identifiable {
    var id: Int
    var key: String
    var name: String
    var latitude: String
    var longitude: String
    
    init(id: Int, key: String, name: String, latitute: String, longitude: String) {
        self.id = id
        self.key = key
        self.name = name
        self.latitude = latitute
        self.longitude = longitude
    }
}
