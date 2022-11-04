//
//  Microbit.swift
//  mbweather
//

import CoreBluetooth

struct Microbit : Identifiable {
    var id: Int
    var uuid: UUID
    var name: String
    var peripheral: CBPeripheral
    init(id: Int, uuid: UUID, name: String, peripheral: CBPeripheral) {
        self.id = id
        self.uuid = uuid
        self.name = name
        self.peripheral = peripheral
    }
}
