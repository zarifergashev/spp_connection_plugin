import Foundation
import CoreBluetooth
import ExternalAccessory

// MARK: - Protocols and Enums
protocol BluetoothManagerDelegate: AnyObject {
    func bluetoothManager(_ manager: BluetoothManager, didUpdateConnectionState state: ConnectionState)
    func bluetoothManager(_ manager: BluetoothManager, didReceiveData data: Data)
    func bluetoothManager(_ manager: BluetoothManager, didUpdateDeviceList devices: [BluetoothDeviceInfo])
    func bluetoothManager(_ manager: BluetoothManager, didEncounterError error: String)
}

enum ConnectionState: Int {
    case disconnected = 0
    case connecting = 1
    case connected = 2
    case disconnecting = 3
}

struct BluetoothDeviceInfo {
    let name: String
    let address: String
    let type: Int
    let bonded: Bool
}

// MARK: - BluetoothManager
class BluetoothManager: NSObject {
    weak var delegate: BluetoothManagerDelegate?

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var targetCharacteristic: CBCharacteristic?
    private var connectionState: ConnectionState = .disconnected

    // External Accessory support for MFi devices
    private var eaSession: EASession?
    private var eaAccessory: EAAccessory?

    // Device discovery
    private var discoveredPeripherals: [CBPeripheral] = []
    private var isScanning = false
    private var connectCompletion: ((Bool, String?) -> Void)?
    private var permissionCompletion: ((Bool) -> Void)?

    // UART Service UUID (Nordic UART Service)
    private let uartServiceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let uartTXCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    private let uartRXCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

    // Serial Port Profile UUID (if supported)
    private let serialPortServiceUUID = CBUUID(string: "00001101-0000-1000-8000-00805F9B34FB")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    init(delegate: BluetoothManagerDelegate) {
        super.init()
        self.delegate = delegate
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Public Methods
    func isBluetoothEnabled() -> Bool {
        return centralManager.state == .poweredOn
    }

    func hasPermissions() -> Bool {
        if #available(iOS 13.1, *) {
            return CBCentralManager.authorization == .allowedAlways
        } else {
            return centralManager.state != .unauthorized
        }
    }

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        permissionCompletion = completion

        if hasPermissions() {
            completion(true)
            return
        }

        // For iOS 13+, permissions are requested automatically when CBCentralManager is created
        // We'll check the state in the delegate callback
        if centralManager.state == .unknown {
            // Wait for state update
            return
        }

        completion(hasPermissions())
    }

    func getPairedDevices() -> [BluetoothDeviceInfo] {
        var devices: [BluetoothDeviceInfo] = []

        // Get previously connected Core Bluetooth devices
        let knownPeripherals = centralManager.retrieveConnectedPeripherals(withServices: [uartServiceUUID, serialPortServiceUUID])

        for peripheral in knownPeripherals {
            devices.append(BluetoothDeviceInfo(
                name: peripheral.name ?? "Unknown Device",
                address: peripheral.identifier.uuidString,
                type: 1, // BLE
                bonded: false // iOS doesn't expose bonding info
            ))
        }

        // Get External Accessory devices (MFi)
        let accessories = EAAccessoryManager.shared().connectedAccessories
        for accessory in accessories {
            // Check if accessory supports serial communication protocols
            let serialProtocols = accessory.protocolStrings.filter { protocolString in
                protocolString.contains("uart") || protocolString.contains("serial") || protocolString.contains("spp")
            }

            if !serialProtocols.isEmpty {
                devices.append(BluetoothDeviceInfo(
                    name: accessory.name,
                    address: accessory.serialNumber,
                    type: 2, // External Accessory
                    bonded: true
                ))
            }
        }

        // Add discovered peripherals
        for peripheral in discoveredPeripherals {
            let deviceExists = devices.contains { device in
                device.address == peripheral.identifier.uuidString
            }
            if !deviceExists {
                devices.append(BluetoothDeviceInfo(
                    name: peripheral.name ?? "Unknown Device",
                    address: peripheral.identifier.uuidString,
                    type: 1,
                    bonded: false
                ))
            }
        }

        return devices
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            delegate?.bluetoothManager(self, didEncounterError: "Bluetooth is not powered on")
            return
        }

        if !isScanning {
            isScanning = true
            centralManager.scanForPeripherals(withServices: [uartServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])

            // Stop scanning after 10 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                self.stopScanning()
            }
        }
    }

    func stopScanning() {
        if isScanning {
            centralManager.stopScan()
            isScanning = false
        }
    }

    func connectToDevice(address: String, completion: @escaping (Bool, String?) -> Void) {
        connectCompletion = completion

        // Check if it's an External Accessory device
        let connectedAccessories = EAAccessoryManager.shared().connectedAccessories
        if let accessory = connectedAccessories.first(where: { $0.serialNumber == address }) {
            connectToExternalAccessory(accessory)
            return
        }

        // Check if it's a Core Bluetooth device
        if let peripheral = discoveredPeripherals.first(where: { $0.identifier.uuidString == address }) {
            connectToPeripheral(peripheral)
            return
        }

        // Try to retrieve peripheral by UUID
        if let uuid = UUID(uuidString: address) {
            let peripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
            if let peripheral = peripherals.first {
                connectToPeripheral(peripheral)
                return
            }
        }

        completion(false, "Device not found")
    }

    private func connectToPeripheral(_ peripheral: CBPeripheral) {
        updateConnectionState(.connecting)
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    private func connectToExternalAccessory(_ accessory: EAAccessory) {
        guard let protocolString = accessory.protocolStrings.first else {
            connectCompletion?(false, "No supported protocols")
            return
        }

        eaAccessory = accessory
        eaSession = EASession(accessory: accessory, forProtocol: protocolString)

        guard let session = eaSession else {
            connectCompletion?(false, "Failed to create session")
            return
        }

        session.inputStream?.delegate = self
        session.outputStream?.delegate = self

        session.inputStream?.schedule(in: .main, forMode: .default)
        session.outputStream?.schedule(in: .main, forMode: .default)

        session.inputStream?.open()
        session.outputStream?.open()

        updateConnectionState(.connected)
        connectCompletion?(true, nil)
        connectCompletion = nil
    }

    func disconnect() {
        updateConnectionState(.disconnecting)

        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }

        if let session = eaSession {
            session.inputStream?.close()
            session.outputStream?.close()
            session.inputStream?.remove(from: .main, forMode: .default)
            session.outputStream?.remove(from: .main, forMode: .default)
        }

        cleanup()
    }

    private func cleanup() {
        connectedPeripheral = nil
        targetCharacteristic = nil
        eaSession = nil
        eaAccessory = nil
        updateConnectionState(.disconnected)
    }

    func sendData(data: Data, completion: @escaping (Bool, String?) -> Void) {
        guard connectionState == .connected else {
            completion(false, "Not connected")
            return
        }

        if let characteristic = targetCharacteristic, let peripheral = connectedPeripheral {
            // Core Bluetooth
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            completion(true, nil)
        } else if let outputStream = eaSession?.outputStream, outputStream.hasSpaceAvailable {
            // External Accessory
            let bytesWritten = data.withUnsafeBytes { bytes in
                return outputStream.write(bytes.bindMemory(to: UInt8.self).baseAddress!, maxLength: data.count)
            }

            if bytesWritten == data.count {
                completion(true, nil)
            } else {
                completion(false, "Failed to write all data")
            }
        } else {
            completion(false, "No available connection")
        }
    }

    private func updateConnectionState(_ state: ConnectionState) {
        connectionState = state
        delegate?.bluetoothManager(self, didUpdateConnectionState: state)
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            permissionCompletion?(true)
        case .unauthorized:
            delegate?.bluetoothManager(self, didEncounterError: "Bluetooth access denied")
            permissionCompletion?(false)
        case .unsupported:
            delegate?.bluetoothManager(self, didEncounterError: "Bluetooth not supported")
            permissionCompletion?(false)
        case .poweredOff:
            delegate?.bluetoothManager(self, didEncounterError: "Bluetooth is powered off")
            permissionCompletion?(false)
        default:
            break
        }
        permissionCompletion = nil
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !discoveredPeripherals.contains(peripheral) {
            discoveredPeripherals.append(peripheral)
            delegate?.bluetoothManager(self, didUpdateDeviceList: getPairedDevices())
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        updateConnectionState(.connected)
        peripheral.discoverServices([uartServiceUUID, serialPortServiceUUID])
        connectCompletion?(true, nil)
        connectCompletion = nil
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        cleanup()
        connectCompletion?(false, error?.localizedDescription ?? "Connection failed")
        connectCompletion = nil
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        cleanup()
        if let error = error {
            delegate?.bluetoothManager(self, didEncounterError: "Disconnected with error: \(error.localizedDescription)")
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        for service in services {
            if service.uuid == uartServiceUUID {
                peripheral.discoverCharacteristics([uartTXCharacteristicUUID, uartRXCharacteristicUUID], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            if characteristic.uuid == uartTXCharacteristicUUID {
                targetCharacteristic = characteristic
            } else if characteristic.uuid == uartRXCharacteristicUUID {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        delegate?.bluetoothManager(self, didReceiveData: data)
    }
}

// MARK: - StreamDelegate (for External Accessory)
extension BluetoothManager: StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .hasBytesAvailable:
            if let inputStream = aStream as? InputStream {
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
                defer { buffer.deallocate() }

                let bytesRead = inputStream.read(buffer, maxLength: 1024)
                if bytesRead > 0 {
                    let data = Data(bytes: buffer, count: bytesRead)
                    delegate?.bluetoothManager(self, didReceiveData: data)
                }
            }
        case .hasSpaceAvailable:
            // Ready to write data
            break
        case .errorOccurred:
            delegate?.bluetoothManager(self, didEncounterError: "Stream error occurred")
        case .endEncountered:
            disconnect()
        default:
            break
        }
    }
}