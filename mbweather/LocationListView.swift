//
//  LocationListView.swift
//  mbweather
//

import SwiftUI

struct LocationListView : View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var appDelegate: AppDelegate
    
    var body: some View {
        VStack {
            LocationListHeaderView(onCloseAction: {
                presentationMode.wrappedValue.dismiss()
            })
            
            List(appDelegate.locationList) { location in
                HStack {
                    Text(location.name)
                    Spacer()
                }.contentShape(Rectangle())
                .onTapGesture {
                    print("\(location.name)がタップされた。")
                    appDelegate.setCurrentLocation(key: location.key)
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

struct LocationListHeaderView : View {
    var onCloseAction: ()-> Void
    
    var body: some View {
        HStack {
            Button("閉じる") {
                onCloseAction()
            }.padding([.top, .leading], 12.0)
            
            Spacer()
        }
    }
}
