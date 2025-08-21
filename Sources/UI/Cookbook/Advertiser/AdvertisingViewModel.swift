//
//  AdvertisingViewModel.swift
//  AsyncBluetoothCookbook
//
//  Created by luca on 18.08.2025.
//

import AsyncBluetooth
import Combine
import CoreBluetooth
import Foundation

enum Cookbook {
    static let serviceUUID: UUID = .init(uuidString: "E88002B2-3A05-4F71-9332-CE59CF8DCDA6")!
    static let peripheralToCentralCharacteristicUUID: UUID = .init(uuidString: "E88002B3-3A05-4F71-9332-CE59CF8DCDA6")!
    static let centralToPeripheralCharacteristicUUID: UUID = .init(uuidString: "E88002B4-3A05-4F71-9332-CE59CF8DCDA6")!
    static var writeType: CBCharacteristicWriteType { .withoutResponse }
    static var writeProperties: CBCharacteristicProperties { [.write, .writeWithoutResponse] }

    struct Message: Codable {
        init(index: Int) {
            self.index = index
        }
        
        let index: Int

        var data: Data {
            get throws {
                try JSONEncoder().encode(self)
            }
        }

        init(data: Data) throws {
            self = try JSONDecoder().decode(Message.self, from: data)
        }
    }
}

@preconcurrency // passing self to task
@Observable
@available(iOS 17.0, *)
final class AdvertisingViewModel {
    let peripheralManager = PeripheralManager(dispatchQueue: .global())

    var isWaitingForAdvertising = false
    var subscribedCentrals = [Central]()
    @ObservationIgnored var centralObserver: AnyCancellable?

    private let peripheralToCentralCharacteristic = MutableCharacteristic(
        type: Cookbook.peripheralToCentralCharacteristicUUID,
        properties: [.notify, .indicate],
        value: nil,
        permissions: [.readable] // write by peripheral, read by central
    )

    let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    var isAdvertising: Bool {
        peripheralManager.isAdvertising
    }

    let exchangeViewModel = DataExchangeViewModel()

    @Bluetooth func startAdvertising() async throws {
        isWaitingForAdvertising = true
        defer {
            isWaitingForAdvertising = false
        }
        try await peripheralManager.waitUntilReady()
        peripheralManager.removeAllServices()
        let centralToPeripheralCharacteristic = MutableCharacteristic(
            type: Cookbook.centralToPeripheralCharacteristicUUID,
            properties: Cookbook.writeProperties,
            value: nil,
            permissions: [.writeable] // write by central, read by peripheral
        )
        let service = MutableService(type: Cookbook.serviceUUID, primary: true)
        service.characteristics = [centralToPeripheralCharacteristic, peripheralToCentralCharacteristic]
        try await peripheralManager.add(service)
        guard !peripheralManager.isAdvertising else {
            return
        }
        try await peripheralManager.startAdvertising(localName: "Cookbook", serviceUUIDs: [
            Cookbook.serviceUUID
        ])
        subscribedCentrals = await peripheralManager.subscribedCentrals.filter { $0.isSubscribed.value }
        centralObserver = peripheralManager.subscribedCentralsPublisher
            .sink { [weak self] newValue in
                self?.subscribedCentrals = newValue.filter({ $0.isSubscribed.value })
            }
    }

    @Bluetooth  func stopAdvertising() async {
        isWaitingForAdvertising = true
        defer {
            isWaitingForAdvertising = false
        }
        peripheralManager.removeAllServices()
        stopDataExchange()
        await peripheralManager.stopAdvertising()
    }

    // Tasks for reading data from the central
    @ObservationIgnored private var requestObserver: AnyCancellable?
    @ObservationIgnored private var lastSentTime: TimeInterval?

    // Task for reading
    func startDataExchange(for central: Central) {
        requestObserver = peripheralManager.writeRequests(for: central)
            .sink { [weak self] requests in
                print("writeRequest update: \(requests.count)")
                guard let self else { return }
                handleWrite(requests: requests)
            }
    }

    func stopDataExchange() {
        [requestObserver].forEach {
            $0?.cancel()
        }
        requestObserver = nil
    }


    private func handleWrite(requests: [ATTRequest]) {
        _handleWrite(requests: requests)
    }

    private func _handleWrite(requests: [ATTRequest])  {
        for request in requests {
            if let data = request.value {
                if !request.characteristic.properties.contains(.writeWithoutResponse) {
                    peripheralManager.respond(to: request, withResult: .success)
                }
                do {
                    let message = try Cookbook.Message(data: data)

                    let current = Date().timeIntervalSinceReferenceDate
                    let item = DataExchangeViewModel.Item(message: "From Scanner: \(message.index)", latency: lastSentTime.flatMap({ current - $0 }))
                    lastSentTime = current
                    exchangeViewModel.items.append(item)
                    Task {
                        do {
                            let response = Cookbook.Message(index: message.index)
                            try await peripheralManager.updateValue(response.data, for: peripheralToCentralCharacteristic, onSubscribedCentrals: [request.central])
                        } catch {
                            print("failed to response: \(error)")
                        }
                    }
                } catch {
                    let item = DataExchangeViewModel.Item(message: "failed to response: \(error)")
                    exchangeViewModel.items.append(item)
                }
            } else {
                peripheralManager.respond(to: request, withResult: .attributeNotFound)
            }
        }
    }
}

@globalActor
actor Bluetooth {
    static let shared = Bluetooth()
}
