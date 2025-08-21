//
//  ScannerViewModel.swift
//  AsyncBluetoothCookbook
//
//  Created by luca on 20.08.2025.
//

import AsyncBluetooth
import Foundation
import Combine

@preconcurrency // passing self to task
@Observable
@available(iOS 17.0, *)
final class ScannerViewModel {
    let centralManager = CentralManager(dispatchQueue: .global())

    let exchangeViewModel = DataExchangeViewModel()

    @ObservationIgnored private var peripheral: Peripheral?
    @ObservationIgnored private var writeCharacteristic: Characteristic?
    @ObservationIgnored private var readCharacteristic: Characteristic?
    @ObservationIgnored private var incomingDataObserver: AnyCancellable?
    @ObservationIgnored private var connectionObserver: AnyCancellable?
    @ObservationIgnored private var lastSentTime: TimeInterval?
    @ObservationIgnored private var pendingMessages: [Cookbook.Message] = []

    var isReadyToWrite = false

    let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func startScanning() async {
        do {
            try await centralManager.waitUntilReady()
            let scanDataStream = try await centralManager.scanForPeripherals(withServices: [CBUUID(nsuuid: Cookbook.serviceUUID)])
            try await filterPeripheralAndCharacteristic(for: scanDataStream)
            setupConnectionObservers()
        } catch {
            print("Cookbook--: failed to start scanning: \(error)")
        }
    }

    func send1000Messages() async {
        guard let peripheral, let characteristic = writeCharacteristic else { return }
        for i in 0..<1000 {
            do {
                let message = Cookbook.Message(index: i)
                try await peripheral.writeValue(message.data, for: characteristic, type: .withoutResponse)
            } catch {
                print("Cookbook--: failed to send \(i): \(error)")
            }
        }
    }

    func startExchangeLoop() async {
        guard let peripheral, let characteristic = writeCharacteristic else { return }
        setupIncomingDataObservers()
        do {
            let message = Cookbook.Message(index: 1000)
            try await peripheral.writeValue(message.data, for: characteristic, type: Cookbook.writeType)
            let item = DataExchangeViewModel.Item(message: "Start with \(message.index)")
            await MainActor.run {
                exchangeViewModel.items.append(item)
            }
        } catch {
            print("Cookbook--: failed to startExchangeLoop: \(error)")
        }
    }

    func cancelAllTasks() async {
        await centralManager.cancelAllOperations()
        await peripheral?.cancelAllOperations()
        [connectionObserver, incomingDataObserver].forEach {
            $0?.cancel()
        }
        if let characteristic = readCharacteristic {
            try? await peripheral?.setNotifyValue(false, for: characteristic)
        }
        peripheral = nil
        writeCharacteristic = nil
        readCharacteristic = nil
    }

    private func filterPeripheralAndCharacteristic(for scanDataStream: AsyncStream<ScanData>) async throws {
        for await scanData in scanDataStream {
            try await centralManager.connect(scanData.peripheral)
            try await scanData.peripheral.discoverServices([CBUUID(nsuuid: Cookbook.serviceUUID)])
            if let service = scanData.peripheral.discoveredServices?.first(where: { $0.uuid.uuidString == Cookbook.serviceUUID.uuidString }) {
                try await scanData.peripheral.discoverCharacteristics(nil, for: service)
                if
                    let writeCharacteristic = service.discoveredCharacteristics?.first(where: { $0.uuid.uuidString == Cookbook.centralToPeripheralCharacteristicUUID.uuidString }),
                    let readCharacteristic = service.discoveredCharacteristics?.first(where: { $0.uuid.uuidString == Cookbook.peripheralToCentralCharacteristicUUID.uuidString })
                {
                    try await scanData.peripheral.setNotifyValue(true, for: readCharacteristic)
                    self.peripheral = scanData.peripheral
                    self.writeCharacteristic = writeCharacteristic
                    self.readCharacteristic = readCharacteristic
                    await centralManager.stopScan()
                    isReadyToWrite = true
                    return
                }
            }
        }
        isReadyToWrite = false
    }

    private func setupIncomingDataObservers() {
        guard let peripheral else {
            return
        }

        incomingDataObserver = peripheral.characteristicValueUpdatedPublisher // only one interested
            .compactMap(\.value)
            .sink { [weak self] value in
                self?.respondToIncomingData(value)
            }
    }

    private func respondToIncomingData(_ value: Data) {
        guard let peripheral, let characteristic = writeCharacteristic else { return }
        Task {
            do {
                let message = try Cookbook.Message(data: value)
                let current = Date().timeIntervalSinceReferenceDate
                let item = DataExchangeViewModel.Item(message: "From Advertiser: \(message.index)", latency: lastSentTime.flatMap({ current - $0 }))
                lastSentTime = current
                let response = Cookbook.Message(index: min(Int.max, message.index + 1))
                try await peripheral.writeValue(response.data, for: characteristic, type: Cookbook.writeType)
                await MainActor.run {
                    exchangeViewModel.items.append(item)
                }
            } catch {
                let item = DataExchangeViewModel.Item(message: "failed to response: \(error)")
                await MainActor.run {
                    exchangeViewModel.items.append(item)
                }
            }
        }
    }

    private func setupConnectionObservers() {
        connectionObserver = centralManager.eventPublisher
            .filter({ [weak self] in
                if case let .didDisconnectPeripheral(peripheral, _, _) = $0 {
                    return peripheral.cbPeripheral == self?.peripheral?.cbPeripheral
                } else {
                    return false
                }
            })
            .map({ _ in })
            .sink { [weak self] in
                self?.isReadyToWrite = false
            }
    }
}
