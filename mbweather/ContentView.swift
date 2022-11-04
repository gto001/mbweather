//
//  ContentView.swift
//  mbweather
//

import SwiftUI

struct ContentView: View {
    @State var deviceName = NO_MICROBIT
    
    var body: some View {
        ZStack {
            HeaderPanel(deviceName: deviceName)
        }
    }
}

struct HeaderPanel : View {
    @State var deviceName = NO_MICROBIT
    @State private var showLocationListView = false
    @State private var showMicrobitListView = false
    @EnvironmentObject var appDelegate: AppDelegate

    var body: some View {
        VStack{
            Button(action: {showLocationListView = true}) {
                Text(appDelegate.currentLocation.name)
                    .font(.title)
                    .frame(width: 250, height: 60, alignment: .center)
                    .overlay(RoundedRectangle(cornerRadius: 20)
                              .stroke(Color.blue, lineWidth: 2))
            }.sheet(isPresented: self.$showLocationListView) {
                LocationListView()
            }
            Button(action: {showMicrobitListView = true}) {
                Text(appDelegate.microbit != nil ? appDelegate.microbit!.name : NO_MICROBIT)
                    .frame(width: 250, height: 60, alignment: .center)
                    .overlay(RoundedRectangle(cornerRadius: 20)
                               .stroke(Color.blue, lineWidth: 2))
            }.sheet(isPresented: self.$showMicrobitListView) {
                MicrobitListView()
            }
        }.frame(width: 320, height: 700, alignment: .center)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
