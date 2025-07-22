import 'dart:typed_data';

import 'package:spp_connection_plugin/src/bluetooth_connection_state.dart';
import 'package:spp_connection_plugin/src/bluetooth_device_model.dart';

import 'spp_connection_plugin_platform_interface.dart';

class SppConnectionPlugin {
  BluetoothConnectionState get connectionState =>
      SppConnectionPluginPlatform.instance.connectionState;

  BluetoothDeviceModel? get connectedDevice => SppConnectionPluginPlatform.instance.connectedDevice;

  bool get hexMode => SppConnectionPluginPlatform.instance.hexMode;

  String get newlineType => SppConnectionPluginPlatform.instance.newlineType;

  Stream<BluetoothConnectionState> get connectionStateStream =>
      SppConnectionPluginPlatform.instance.connectionStateStream;

  Stream<Uint8List> get dataStream => SppConnectionPluginPlatform.instance.dataStream;

  Stream<List<BluetoothDeviceModel>> get deviceListStream =>
      SppConnectionPluginPlatform.instance.deviceListStream;

  Future<String?> getPlatformVersion() {
    return SppConnectionPluginPlatform.instance.getPlatformVersion();
  }

  Future<bool> isBluetoothSupported() =>
      SppConnectionPluginPlatform.instance.isBluetoothSupported();

  Future<bool> isBluetoothEnabled() => SppConnectionPluginPlatform.instance.isBluetoothEnabled();

  Future<void> enableBluetooth() => SppConnectionPluginPlatform.instance.enableBluetooth();

  Future<bool> hasPermissions() => SppConnectionPluginPlatform.instance.hasPermissions();

  Future<bool> requestPermissions() => SppConnectionPluginPlatform.instance.requestPermissions();

  Future<List<BluetoothDeviceModel>> getPairedDevices() =>
      SppConnectionPluginPlatform.instance.getPairedDevices();

  Future<void> connectToDevice(String address) =>
      SppConnectionPluginPlatform.instance.connectToDevice(address);

  Future<void> disconnect() => SppConnectionPluginPlatform.instance.disconnect();

  Future<void> sendData(Uint8List data) => SppConnectionPluginPlatform.instance.sendData(data);

  Future<void> sendText(String text) => SppConnectionPluginPlatform.instance.sendText(text);

  Future<void> sendHex(String hexString) => SppConnectionPluginPlatform.instance.sendHex(hexString);

  void setHexMode(bool enabled) => SppConnectionPluginPlatform.instance.setHexMode(enabled);

  void setNewlineType(String newline) =>
      SppConnectionPluginPlatform.instance.setNewlineType(newline);

  Future<void> startBackgroundService() =>
      SppConnectionPluginPlatform.instance.startBackgroundService();

  Future<void> stopBackgroundService() =>
      SppConnectionPluginPlatform.instance.stopBackgroundService();

  Future<bool> areNotificationsEnabled() =>
      SppConnectionPluginPlatform.instance.areNotificationsEnabled();

  Future<void> openNotificationSettings() =>
      SppConnectionPluginPlatform.instance.openNotificationSettings();

  Future<void> openBluetoothSettings() =>
      SppConnectionPluginPlatform.instance.openBluetoothSettings();
}
