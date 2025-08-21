//
//  DataExchangeView.swift
//  AsyncBluetoothCookbook
//
//  Created by luca on 18.08.2025.
//

import SwiftUI

@available(iOS 17.0, *)
@Observable class DataExchangeViewModel {
    struct Item {
        let message: String
        var latency: Double?
    }

    var items: [Item] = []
}

@available(iOS 17.0, *)
struct DataExchangeView: View {
    @Environment(DataExchangeViewModel.self) var viewModel
    var body: some View {
        List(viewModel.items.indices, id: \.self) { idx in
            let item = viewModel.items[idx]
            VStack(alignment: .leading) {
                Text("\(item.message)").font(.title)
                if let latency = item.latency {
                    Text("Latency: \(latency*100, specifier: "%.3f")ms").font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toolbar {
            if viewModel.items.count > 0 {
                ToolbarItem(placement: .title) {
                    Text("\(viewModel.items.count) items")
                }
            }
            if viewModel.items.count > 0 {
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear") {
                        viewModel.items.removeAll()
                    }
                }
            }
        }
    }
}
