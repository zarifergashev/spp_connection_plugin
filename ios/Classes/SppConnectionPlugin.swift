// ios/Classes/SppConnectionPlugin.swift
import Flutter
import UIKit
import CoreBluetooth
import ExternalAccessory
import UserNotifications

public class SppConnectionPlugin: NSObject, FlutterPlugin {
    private var methodChannel: FlutterMethodChannel!
    private var connectionStateEventChannel: FlutterEventChannel!
    private var dataEventChannel: FlutterEventChannel!
    private var deviceListEventChannel: FlutterEventChannel!

    // These need to be internal so stream handlers can access them
    var connectionStateEventSink: FlutterEventSink?
    var dataEventSink: FlutterEventSink?
    var deviceListEventSink: FlutterEventSink?

    private var bluetoothManager: BluetoothManager?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SppConnectionPlugin()
        instance.setupChannels(with: registrar)
    }

    private func setupChannels(with registrar: FlutterPluginRegistrar) {
        methodChannel = FlutterMethodChannel(name: "flutter_bluetooth_terminal/methods", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(self, channel: methodChannel)

        connectionStateEventChannel = FlutterEventChannel(name: "flutter_bluetooth_terminal/connection_state", binaryMessenger: registrar.messenger())
        connectionStateEventChannel.setStreamHandler(ConnectionStateStreamHandler(plugin: self))

        dataEventChannel = FlutterEventChannel(name: "flutter_bluetooth_terminal/data", binaryMessenger: registrar.messenger())
        dataEventChannel.setStreamHandler(DataStreamHandler(plugin: self))

        deviceListEventChannel = FlutterEventChannel(name: "flutter_bluetooth_terminal/device_list", binaryMessenger: registrar.messenger())
        deviceListEventChannel.setStreamHandler(DeviceListStreamHandler(plugin: self))

        bluetoothManager = BluetoothManager(delegate: self)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let bluetoothManager = bluetoothManager else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Bluetooth manager not initialized", details: nil))
            return
        }

        switch call.method {
        case "isBluetoothSupported":
            result(true)
        case "isBluetoothEnabled":
            result(bluetoothManager.isBluetoothEnabled())
        case "enableBluetooth":
            handleOpenBluetoothSettings(result: result)
        case "hasPermissions":
            result(bluetoothManager.hasPermissions())
        case "requestPermissions":
            bluetoothManager.requestPermissions { granted in
                DispatchQueue.main.async {
                    result(granted)
                }
            }
        case "getPairedDevices":
            let devices = bluetoothManager.getPairedDevices()
            let deviceMaps = devices.map { device in
                return [
                    "name": device.name,
                    "address": device.address,
                    "type": device.type,
                    "bonded": device.bonded
                ]
            }
            result(deviceMaps)
        case "connectToDevice":
            guard let args = call.arguments as? [String: Any],
                  let address = args["address"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Device address is required", details: nil))
                return
            }
            bluetoothManager.connectToDevice(address: address) { success, error in
                DispatchQueue.main.async {
                    if success {
                        result(nil)
                    } else {
                        result(FlutterError(code: "CONNECTION_FAILED", message: error ?? "Failed to connect", details: nil))
                    }
                }
            }
        case "disconnect":
            bluetoothManager.disconnect()
            result(nil)
        case "sendData":
            guard let args = call.arguments as? [String: Any],
                  let data = args["data"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Data is required", details: nil))
                return
            }
            bluetoothManager.sendData(data: data.data) { success, error in
                DispatchQueue.main.async {
                    if success {
                        result(nil)
                    } else {
                        result(FlutterError(code: "SEND_FAILED", message: error ?? "Failed to send data", details: nil))
                    }
                }
            }
        case "startBackgroundService":
            result(nil)
        case "stopBackgroundService":
            result(nil)
        case "areNotificationsEnabled":
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    result(settings.authorizationStatus == .authorized)
                }
            }
        case "openNotificationSettings":
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl) { success in
                    result(success)
                }
            } else {
                result(false)
            }
        case "openBluetoothSettings":
            handleOpenBluetoothSettings(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleOpenBluetoothSettings(result: @escaping FlutterResult) {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl) { success in
                result(success)
            }
        } else {
            result(false)
        }
    }
}

// MARK: - BluetoothManagerDelegate
extension SppConnectionPlugin: BluetoothManagerDelegate {
    func bluetoothManager(_ manager: BluetoothManager, didUpdateConnectionState state: ConnectionState) {
        connectionStateEventSink?(["state": state.rawValue])
    }

    func bluetoothManager(_ manager: BluetoothManager, didReceiveData data: Data) {
        dataEventSink?(["data": FlutterStandardTypedData(bytes: data)])
    }

    func bluetoothManager(_ manager: BluetoothManager, didUpdateDeviceList devices: [BluetoothDeviceInfo]) {
        let deviceMaps = devices.map { device in
            return [
                "name": device.name,
                "address": device.address,
                "type": device.type,
                "bonded": device.bonded
            ]
        }
        deviceListEventSink?(["devices": deviceMaps])
    }

    func bluetoothManager(_ manager: BluetoothManager, didEncounterError error: String) {
        connectionStateEventSink?(FlutterError(code: "BLUETOOTH_ERROR", message: error, details: nil))
    }
}

// MARK: - Stream Handlers
class ConnectionStateStreamHandler: NSObject, FlutterStreamHandler {
    private weak var plugin: SppConnectionPlugin?

    init(plugin: SppConnectionPlugin) {
        self.plugin = plugin
        super.init()
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        plugin?.connectionStateEventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin?.connectionStateEventSink = nil
        return nil
    }
}

class DataStreamHandler: NSObject, FlutterStreamHandler {
    private weak var plugin: SppConnectionPlugin?
    
    init(plugin: SppConnectionPlugin) {
        self.plugin = plugin
        super.init()
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        plugin?.dataEventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin?.dataEventSink = nil
        return nil
    }
}

class DeviceListStreamHandler: NSObject, FlutterStreamHandler {
    private weak var plugin: SppConnectionPlugin?
    
    init(plugin: SppConnectionPlugin) {
        self.plugin = plugin
        super.init()
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        plugin?.deviceListEventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin?.deviceListEventSink = nil
        return nil
    }
}