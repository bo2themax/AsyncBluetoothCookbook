//
//  ScannerView.swift
//  AsyncBluetoothCookbook
//
//  Created by luca on 20.08.2025.
//

import SwiftUI

@available(iOS 17.0, *)
struct ScannerView: View {
    let viewModel = ScannerViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        DataExchangeView()
            .task {
                await viewModel.startScanning()
            }
            .onDisappear {
                Task {
                    await viewModel.cancelAllTasks()
                }
            }
            .environment(viewModel.exchangeViewModel)
            .onChange(of: viewModel.isReadyToWrite, initial: false) { _, newValue in
                if !newValue {
                    dismiss()
                }
            }
            .overlay(alignment: .bottom) {
                if viewModel.isReadyToWrite {
                    HStack {
                        Button("Send 1000 Messages") {
                            Task {
                                await viewModel.send1000Messages()
                            }
                        }

                        Spacer()

                        Button("Start Exchange") {
                            Task {
                                await viewModel.startExchangeLoop()
                            }
                        }
                    }
                    .padding()
                    .background()
                }
            }
            .toolbar {
                if !viewModel.isReadyToWrite {
                    ToolbarItem(placement: .primaryAction) {
                        ProgressView().progressViewStyle(.circular)
                    }
                }
            }
    }
}
