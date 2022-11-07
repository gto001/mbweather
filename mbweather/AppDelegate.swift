//
//  AppDelegate.swift
//  mbweather
//

import SwiftUI
import CoreBluetooth

let NO_MICROBIT = "No micro:bit"
let DEFAULT_LOCATION = Location(id: 1000,
                                key: "tokyo",
                                name: "東京",
                                latitute: "35.689185",
                                longitude: "139.691648")

let MICROBIT_UART_SERVICE = CBUUID(string: "6e400001-b5a3-f393-e0a9-e50e24dcca9e")
let MICROBIT_TX_CHARACTERISTIC =
    CBUUID(string: "6e400002-b5a3-f393-e0a9-e50e24dcca9e")
let MICROBIT_RX_CHARACTERISTIC =
    CBUUID(string: "6e400003-b5a3-f393-e0a9-e50e24dcca9e")

extension URLComponents {
    mutating func setQueryItems(with parameters: [String: String]) {
        self.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
    }
}

class AppDelegate : UIResponder, UIApplicationDelegate,
                        CBCentralManagerDelegate,
                        CBPeripheralDelegate, ObservableObject {
    @Published var locationList: [Location] = []
    @Published var currentLocation = DEFAULT_LOCATION
    @Published var weatherList: [Weather] = []
    
    @Published var microbitList: [Microbit] = []
    @Published var microbit: Microbit?
    private var microbitConnecting: Microbit?
    @Published var blueToothStatus = false
    
    private var cm: CBCentralManager!
    private var deviceIndex: Int = 0;
    var microbitDevice: CBPeripheral?
    var microbitRxChar: CBCharacteristic?
    
    let TIME_ZONE="Asia/Tokyo"
    
    let W_HARE = ""
    let W_HARE_KUMORI = "3"
    let W_KUMORI = "2"
    let W_AME = "1"
    let W_YUKI = "0"
    
    let userDefaults = UserDefaults.standard
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        userDefaults.register(defaults: ["location": "tokyo"])
        
        guard let fileURL = Bundle.main.url(forResource: "pref_lat_lon", withExtension: "txt") else { fatalError("ファイルが見つからない") }
        guard let fileContents = try? String(contentsOf: fileURL) else {
            fatalError("ファイル読み込みエラー")
        }
        let locations = fileContents.components(separatedBy: "\n")
        var i = 0
        for locationLine in locations {
            if(i == 0) {
                i += 1
                continue
            }
            if(locationLine.count == 0) {
                continue
            }
            
            let values = locationLine.components(separatedBy: ",")
            locationList += [Location(id: i, key: values[0],
                                      name: values[1],
                                      latitute: values[2],
                                      longitude: values[3])]
            i += 1
        }
        
        let location: String = userDefaults.object(forKey: "location") as! String
        setCurrentLocation(key: location)
        
        // ble初期化
        cm = CBCentralManager(delegate: self, queue:nil)
        return true
    }
    
    func setCurrentLocation(key: String) {
        for location in locationList {
            if(location.key == key) {
                print("set location\(key)")
                userDefaults.set(key, forKey: "location")
                currentLocation = location
            }
        }
        
        loadWeatherForecast()
    }
    
    // https://api.open-meteo.com/v1/forecast?latitude=35.6785&longitude=139.6823&daily=weathercode,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min&timezone=Asia%2FTokyo
    
    func loadWeatherForecast() {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "api.open-meteo.com"
        urlComponents.path = "/v1/forecast"
        let queryParams: [String: String] = [
            "daily": "weathercode,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min",
            "timezone": TIME_ZONE,
            "latitude": currentLocation.latitude,
            "longitude": currentLocation.longitude
        ]
        urlComponents.setQueryItems(with: queryParams)
        // print(urlComponents.url?.absoluteString)
        
        let request = URLRequest(url: urlComponents.url!)
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data else { return }
 
            do {
                let dic = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                
                guard let daily = dic?["daily"] as? [String: Any] else { return }
                guard let time = daily["time"] as? [String] else { return }
                guard let weatherCode = daily["weathercode"] as? [Int64] else { return }
                guard let temperatureMin = daily["temperature_2m_min"] as? [Double] else { return }
                guard let temperatureMax = daily["temperature_2m_max"] as? [Double] else { return }
                guard let apparentTemperatureMin = daily["apparent_temperature_min"] as? [Double] else { return }
                guard let apparentTemperatureMax = daily["apparent_temperature_max"] as? [Double] else { return }

                let dataCount = time.count
                var wlist: [Weather] = []
                
                if weatherCode.count == dataCount &&
                    temperatureMin.count == dataCount &&
                    temperatureMax.count == dataCount &&
                    apparentTemperatureMin.count == dataCount &&
                    apparentTemperatureMax.count == dataCount {

                    for i in 0 ..< time.count {
                        wlist += [Weather(date: time[i],
                                                     weatherCode: weatherCode[i],
                                                     temperatureMin: temperatureMin[i],
                                                     temperatureMax: temperatureMax[i],
                                                     apparentTemperatureMin: apparentTemperatureMin[i],
                                                     apparentTemperatureMax: apparentTemperatureMax[i])]
                    }

                }
                DispatchQueue.main.async {
                    self.weatherList = wlist
                    self.sendWeather()
                }
            } catch {
                print(error.localizedDescription)
            }
        }
        task.resume()
    }
    
    func scanMicrobit(forUI: Bool) {
        microbitList = []
        deviceIndex = 0
        if let device = microbitDevice {
            print("cancelPeripheralConnection")
            cm.cancelPeripheralConnection(device)
        }
        microbitDevice = nil
        microbitRxChar = nil
        microbitConnecting = nil
        microbit = nil
        if(forUI) {
            userDefaults.removeObject(forKey: "microbit_name")
        }
        print("------ scan start -------")
        // BLEデバイスの検出を開始.
        cm.scanForPeripherals(withServices: nil, options: nil)
    }
    
    func stopScanMicrobit() {
        cm.stopScan()
    }
    
    func setMicrobit(microbit: Microbit) {
        print("接続開始")
        self.microbitConnecting = microbit
        if let mb = self.microbitConnecting {
            cm.connect(mb.peripheral, options: nil)
        }
    }
    
    func sendWeather() {
        let dt = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.timeZone = TimeZone(identifier:  "Asia/Tokyo")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dtStr = dateFormatter.string(from: dt)
        
        for weather in weatherList {
            if dtStr != weather.date {
                continue
            }
            
            var data = ""
            if(weather.weatherCode == 0) {
                data = W_HARE
            } else if(weather.weatherCode == 1) {
                data = W_HARE_KUMORI
            } else if(weather.weatherCode == 2) {
                data = W_HARE_KUMORI
            } else if(weather.weatherCode == 3) {
                data = W_KUMORI
            } else if(weather.weatherCode <= 49) {
                data = W_AME
            } else if(weather.weatherCode <= 59) {
                data = W_AME
            } else if(weather.weatherCode <= 69) {
                data = W_AME
            } else if(weather.weatherCode <= 79) {
                data = W_YUKI
            } else if(weather.weatherCode <= 84) {
                data = W_AME
            } else if(weather.weatherCode <= 94) {
                data = W_YUKI
            } else if(weather.weatherCode <= 99) {
                data = W_AME
            } else {
                data = W_HARE
            }
            data += "\n"
            data += String(weather.temperatureMin)
            data += "\n"
            data += String(weather.temperatureMax)
            data += "\n"
            sendToMicrobit(str: data)
            break
        }
    }
    
    func sendToMicrobit(str: String) {
        if let device = microbitDevice {
            if let char = microbitRxChar {
                device.writeValue(toCmd(str: str), for: char, type: CBCharacteristicWriteType.withResponse)
                print("send:\(str)")
            }
        }
    }
    
    private func toCmd(str: String) -> Data {
        let buf = "\(str)"
        print("[\(buf)]")
        var arr = [UInt8]()
        for c in buf.utf8 {
            arr.append(c)
        }
        return Data(bytes: arr)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("state \(central.state)")
        switch (central.state) {
        case .poweredOff:
            print("Bluetoothの電源がOff")
        case .poweredOn:
            print("Bluetoothの電源はOn")
            let mbname: String =
                userDefaults.object(forKey: "microbit_name") as? String ?? ""
            if(!mbname.isEmpty) {
                scanMicrobit(forUI: false)
            }
        case .resetting:
            print("レスティング状態")
        case .unauthorized:
            print("非認証状態")
        case .unknown:
            print("不明")
        case .unsupported:
            print("非対応")
        @unknown default:
            print("不明なステータス:\(central.state)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if let dName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            print("device:\(dName),uuid:\(peripheral.identifier)")
            
            // デバイス名確認
            if dName.hasPrefix("BBC micro:bit") {
                // サービス確認
                let mb = Microbit(id: deviceIndex,
                              uuid: peripheral.identifier,
                              name: dName,
                              peripheral: peripheral)
                microbitList += [mb]
                deviceIndex += 1
                
                let mbname: String = userDefaults.object(forKey: "microbit_name") as? String ?? ""
                if(mbname == dName) {
                    stopScanMicrobit()
                    setMicrobit(microbit: mb)
                }
            }
        }
    }
    
    // peripheralと接続成功
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("デバイスと接続成功")
        
        self.microbitDevice = peripheral
        // デバイスのdelegate設定
        peripheral.delegate = self
        
        // サービスのUUIDを確認
        peripheral.discoverServices([MICROBIT_UART_SERVICE,
                                     MICROBIT_RX_CHARACTERISTIC])
    }
    
    // peripheralと接続失敗
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        
        print("デバイスと接続失敗,\ncause:\(error)")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("デバイス切断")
    }
    
    // peripheralサービス検索結果
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil {
            // サービス確認失敗
            print("サービス確認失敗\ncause:\(error!)")
        } else {
            // サービス確認成功
            print("サービス確認成功")
            let microbitService = peripheral.services?.filter({$0.uuid == MICROBIT_UART_SERVICE})[0]
            peripheral.discoverCharacteristics(
                [MICROBIT_RX_CHARACTERISTIC,
                 MICROBIT_TX_CHARACTERISTIC],
                for: microbitService!)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil {
            print("Characteristics確認:エラー")
            print("cause:\(error!)")
        } else {
            print("Characteristics確認:成功")
            microbitRxChar = service.characteristics!.filter({$0.uuid == MICROBIT_RX_CHARACTERISTIC})[0]
            self.microbit = self.microbitConnecting
            self.microbitConnecting = nil
            userDefaults.set(self.microbit?.name, forKey: "microbit_name")
            sendWeather()
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print("Characteristics読込:エラー")
            print("cause:\(error!)")
        } else {
            print("Characteristics:\(characteristic.value)")
            if let data = characteristic.value {
                let str = String(data: data, encoding: .utf8)
                print("receive:\(str)")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            
            print(error!)
            
        } else {
            if let data = characteristic.value {
                let str = String(data: data, encoding: .utf8)
                print("send:\(str)")
            }
        }
    }
}
