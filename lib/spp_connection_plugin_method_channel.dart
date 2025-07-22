import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:spp_connection_plugin/src/bluetooth_connection_state.dart';
import 'package:spp_connection_plugin/src/bluetooth_device_model.dart';
import 'package:spp_connection_plugin/src/bluetooth_exception.dart';
import 'package:spp_connection_plugin/src/text_utils.dart';

import 'spp_connection_plugin_platform_interface.dart';

/// An implementation of [SppConnectionPluginPlatform] that uses method channels.
class MethodChannelSppConnectionPlugin extends SppConnectionPluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('spp_connection_plugin');

  final MethodChannel _methodChannel = const MethodChannel('flutter_bluetooth_terminal/methods');
  final EventChannel _connectionStateChannel = const EventChannel('flutter_bluetooth_terminal/connection_state');
  final EventChannel _dataChannel = const EventChannel('flutter_bluetooth_terminal/data');
  final EventChannel _deviceListChannel = const EventChannel('flutter_bluetooth_terminal/device_list');

  // Streams
  Stream<BluetoothConnectionState>? _connectionStateStream;
  Stream<Uint8List>? _dataStream;
  Stream<List<BluetoothDeviceModel>>? _deviceListStream;
  // Current state
  BluetoothConnectionState _currentState = BluetoothConnectionState.disconnected;
  BluetoothDeviceModel? _connectedDevice;
  bool _hexMode = false;
  String _newlineType = TextUtils.newlineCRLF;

  /// Get current connection state
  @override
  BluetoothConnectionState get connectionState => _currentState;

  /// Get currently connected device
  @override
  BluetoothDeviceModel? get connectedDevice => _connectedDevice;

  /// Get hex mode status
  @override
  bool get hexMode => _hexMode;

  /// Get newline type
  @override
  String get newlineType => _newlineType;

  /*  static FlutterBluetoothTerminal? _instance;

  FlutterBluetoothTerminal._internal();

  static FlutterBluetoothTerminal get instance {
    _instance ??= FlutterBluetoothTerminal._internal();
    return _instance!;
  }*/

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  /// Stream of connection state changes
  @override
  Stream<BluetoothConnectionState> get connectionStateStream {
    _connectionStateStream ??= _connectionStateChannel
        .receiveBroadcastStream()
        .map((event) {
      final state = BluetoothConnectionState.values[event['state']];
      _currentState = state;
      if (state == BluetoothConnectionState.disconnected) {
        _connectedDevice = null;
      }
      return state;
    });
    return _connectionStateStream!;
  }

  /// Stream of incoming data
  @override
  Stream<Uint8List> get dataStream {
    _dataStream ??= _dataChannel
        .receiveBroadcastStream()
        .map((event) => Uint8List.fromList(List<int>.from(event['data'])));
    return _dataStream!;
  }

  /// Stream of available devices
  @override
  Stream<List<BluetoothDeviceModel>> get deviceListStream {
    _deviceListStream ??= _deviceListChannel
        .receiveBroadcastStream()
        .map((event) => (event['devices'] as List)
        .map((device) => BluetoothDeviceModel.fromMap(Map<String, dynamic>.from(device)))
        .toList());
    return _deviceListStream!;
  }

  /// Check if Bluetooth is supported
  @override
  Future<bool> isBluetoothSupported() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isBluetoothSupported');
      return result ?? false;
    } catch (e) {
      throw BluetoothException('Failed to check Bluetooth support: $e');
    }
  }

  /// Check if Bluetooth is enabled
  @override
  Future<bool> isBluetoothEnabled() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isBluetoothEnabled');
      return result ?? false;
    } catch (e) {
      throw BluetoothException('Failed to check Bluetooth status: $e');
    }
  }

  /// Enable Bluetooth
  @override
  Future<void> enableBluetooth() async {
    try {
      await _methodChannel.invokeMethod('enableBluetooth');
    } catch (e) {
      throw BluetoothException('Failed to enable Bluetooth: $e');
    }
  }

  /// Check if permissions are granted
  @override
  Future<bool> hasPermissions() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('hasPermissions');
      return result ?? false;
    } catch (e) {
      throw BluetoothException('Failed to check permissions: $e');
    }
  }

  /// Request Bluetooth permissions
  @override
  Future<bool> requestPermissions() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('requestPermissions');
      return result ?? false;
    } catch (e) {
      throw BluetoothException('Failed to request permissions: $e');
    }
  }

  /// Get list of paired devices
  @override
  Future<List<BluetoothDeviceModel>> getPairedDevices() async {
    try {
      final result = await _methodChannel.invokeMethod<List>('getPairedDevices');
      return (result ?? [])
          .map((device) => BluetoothDeviceModel.fromMap(Map<String, dynamic>.from(device)))
          .toList();
    } catch (e) {
      throw BluetoothException('Failed to get paired devices: $e');
    }
  }

  /// Connect to a Bluetooth device
  @override
  Future<void> connectToDevice(String address) async {
    try {
      await _methodChannel.invokeMethod('connectToDevice', {
        'address': address,
      });
    } catch (e) {
      throw BluetoothException('Failed to connect to device: $e');
    }
  }

  /// Disconnect from current device
  @override
  Future<void> disconnect() async {
    try {
      await _methodChannel.invokeMethod('disconnect');
    } catch (e) {
      throw BluetoothException('Failed to disconnect: $e');
    }
  }

  /// Send data to connected device
  @override
  Future<void> sendData(Uint8List data) async {
    if (_currentState != BluetoothConnectionState.connected) {
      throw BluetoothException('Not connected to any device');
    }

    try {
      await _methodChannel.invokeMethod('sendData', {
        'data': data,
      });
    } catch (e) {
      throw BluetoothException('Failed to send data: $e');
    }
  }

  /// Send text data (with newline handling)
  @override
  Future<void> sendText(String text) async {
    final textToSend = text + _newlineType;
    final data = Uint8List.fromList(textToSend.codeUnits);
    await sendData(data);
  }

  /// Send hex data
  @override
  Future<void> sendHex(String hexString) async {
    try {
      final data = TextUtils.fromHexString(hexString);
      final dataWithNewline = Uint8List.fromList([...data, ..._newlineType.codeUnits]);
      await sendData(dataWithNewline);
    } catch (e) {
      throw BluetoothException('Invalid hex string: $e');
    }
  }

  /// Set hex mode
  @override
  void setHexMode(bool enabled) {
    _hexMode = enabled;
  }

  /// Set newline type
  @override
  void setNewlineType(String newline) {
    if ([TextUtils.newlineCR, TextUtils.newlineLF, TextUtils.newlineCRLF].contains(newline)) {
      _newlineType = newline;
    } else {
      throw ArgumentError('Invalid newline type');
    }
  }

  /// Start background service
  @override
  Future<void> startBackgroundService() async {
    try {
      await _methodChannel.invokeMethod('startBackgroundService');
    } catch (e) {
      throw BluetoothException('Failed to start background service: $e');
    }
  }

  /// Stop background service
  @override
  Future<void> stopBackgroundService() async {
    try {
      await _methodChannel.invokeMethod('stopBackgroundService');
    } catch (e) {
      throw BluetoothException('Failed to stop background service: $e');
    }
  }

  /// Check if notifications are enabled (Android O+)
  @override
  Future<bool> areNotificationsEnabled() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('areNotificationsEnabled');
      return result ?? true;
    } catch (e) {
      return true; // Default to true for older Android versions
    }
  }

  /// Open notification settings
  @override
  Future<void> openNotificationSettings() async {
    try {
      await _methodChannel.invokeMethod('openNotificationSettings');
    } catch (e) {
      throw BluetoothException('Failed to open notification settings: $e');
    }
  }

  /// Open Bluetooth settings
  @override
  Future<void> openBluetoothSettings() async {
    try {
      await _methodChannel.invokeMethod('openBluetoothSettings');
    } catch (e) {
      throw BluetoothException('Failed to open Bluetooth settings: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _connectionStateStream = null;
    _dataStream = null;
    _deviceListStream = null;
  }
}
