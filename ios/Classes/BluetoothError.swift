import Foundation

enum BluetoothError: Error {
    case notSupported
    case notEnabled
    case permissionDenied
    case deviceNotFound
    case connectionFailed
    case notConnected
    case invalidData
    case timeout
    case unknown(String)

    var localizedDescription: String {
        switch self {
        case .notSupported:
            return BluetoothConstants.bluetoothNotSupported
        case .notEnabled:
            return BluetoothConstants.bluetoothNotEnabled
        case .permissionDenied:
            return BluetoothConstants.permissionDenied
        case .deviceNotFound:
            return BluetoothConstants.deviceNotFound
        case .connectionFailed:
            return BluetoothConstants.connectionFailed
        case .notConnected:
            return BluetoothConstants.notConnected
        case .invalidData:
            return BluetoothConstants.invalidData
        case .timeout:
            return "Operation timed out"
        case .unknown(let message):
            return message
        }
    }
}