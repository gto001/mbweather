//
//  MicrobitListView.swift
//  mbweather
//

import SwiftUI

struct MicrobitListView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var appDelegate: AppDelegate
    
    var body: some View {
        VStack {
            LocationListHeaderView(onCloseAction: {
                presentationMode.wrappedValue.dismiss()
            })
            
            List(appDelegate.microbitList) { microbit in
                HStack {
                    Text(microbit.name)
                    Spacer()
                }.contentShape(Rectangle())
                .onTapGesture {
                    print("\(microbit.name)がタップされた。")
                    appDelegate.stopScanMicrobit()
                    appDelegate.setMicrobit(microbit: microbit)
                    // ToDo select microbit
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }.onAppear() {
            appDelegate.scanMicrobit(forUI: true)
        }.onDisappear() {
            appDelegate.stopScanMicrobit()
        }
    }
}

struct MicrobitListView_Previews: PreviewProvider {
    static var previews: some View {
        MicrobitListView()
    }
}

struct MicrobitListHeaderView : View {
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
