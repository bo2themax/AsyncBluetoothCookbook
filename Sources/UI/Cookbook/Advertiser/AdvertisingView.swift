//
//  AdvertisingView.swift
//  AsyncBluetoothCookbook
//
//  Created by luca on 18.08.2025.
//

import CoreBluetooth
import SwiftUI

@available(iOS 17.0, *)
struct AdvertisingView: View {
    let viewModel = AdvertisingViewModel()
    var body: some View {
        List(viewModel.subscribedCentrals, id: \.identifier) { central in
            NavigationLink(central.identifier.uuidString) {
                DataExchangeView()
                    .environment(viewModel.exchangeViewModel)
                    .task {
                        viewModel.startDataExchange(for: central)
                    }
                    .onDisappear {
                        viewModel.stopDataExchange()
                    }
            }
        }
        .toolbar {
            Button(viewModel.isAdvertising ? "Stop" : "Start") {
                Task {
                    do {
                        if viewModel.isAdvertising {
                            await viewModel.stopAdvertising()
                        } else {
                            try await viewModel.startAdvertising()
                        }
                    } catch {
                        print("failed to advertise:", error)
                    }
                }
            }
            .disabled(viewModel.isWaitingForAdvertising)
        }
    }
}
