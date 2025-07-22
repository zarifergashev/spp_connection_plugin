import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:spp_connection_plugin/src/bluetooth_connection_state.dart';
import 'package:spp_connection_plugin/src/bluetooth_device_model.dart';

import 'spp_connection_plugin_method_channel.dart';

abstract class SppConnectionPluginPlatform extends PlatformInterface {
  /// Constructs a SppConnectionPluginPlatform.
  SppConnectionPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static SppConnectionPluginPlatform _instance = MethodChannelSppConnectionPlugin();

  /// The default instance of [SppConnectionPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelSppConnectionPlugin].
  static SppConnectionPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [SppConnectionPluginPlatform] when
  /// they register themselves.
  static set instance(SppConnectionPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  BluetoothConnectionState get connectionState => throw UnimplementedError('isBluetoothSupported() has not been implemented.');
  BluetoothDeviceModel? get connectedDevice => throw UnimplementedError('isBluetoothSupported() has not been implemented.');
  bool get hexMode => throw UnimplementedError('isBluetoothSupported() has not been implemented.');
  String get newlineType => throw UnimplementedError('isBluetoothSupported() has not been implemented.');
  Stream<BluetoothConnectionState> get connectionStateStream => throw UnimplementedError('isBluetoothSupported() has not been implemented.');
  Stream<Uint8List> get dataStream => throw UnimplementedError('isBluetoothSupported() has not been implemented.');
  Stream<List<BluetoothDeviceModel>> get deviceListStream => throw UnimplementedError('isBluetoothSupported() has not been implemented.');

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<bool> isBluetoothSupported(){  throw UnimplementedError('isBluetoothSupported() has not been implemented.');}
  Future<bool> isBluetoothEnabled(){  throw UnimplementedError('isBluetoothEnabled() has not been implemented.');}
  Future<void> enableBluetooth(){  throw UnimplementedError('enableBluetooth() has not been implemented.');}
  Future<bool> hasPermissions(){  throw UnimplementedError('hasPermissions() has not been implemented.');}
  Future<bool> requestPermissions(){  throw UnimplementedError('requestPermissions() has not been implemented.');}
  Future<List<BluetoothDeviceModel>> getPairedDevices(){  throw UnimplementedError('getPairedDevices() has not been implemented.');}
  Future<void> connectToDevice(String address){  throw UnimplementedError('connectToDevice() has not been implemented.');}
  Future<void> disconnect(){  throw UnimplementedError('disconnect() has not been implemented.');}
  Future<void> sendData(Uint8List data){  throw UnimplementedError(' sendData has not been implemented.');}
  Future<void> sendText(String text){  throw UnimplementedError(' sendText has not been implemented.');}
  Future<void> sendHex(String hexString){  throw UnimplementedError('sendHex  has not been implemented.');}
  void setHexMode(bool enabled){  throw UnimplementedError(' setHexMode has not been implemented.');}
  void setNewlineType(String newline){  throw UnimplementedError('setNewlineType() has not been implemented.');}
  Future<void> startBackgroundService(){  throw UnimplementedError('startBackgroundService() has not been implemented.');}
  Future<void> stopBackgroundService(){  throw UnimplementedError('stopBackgroundService() has not been implemented.');}
  Future<bool> areNotificationsEnabled(){  throw UnimplementedError('areNotificationsEnabled() has not been implemented.');}
  Future<void> openNotificationSettings(){  throw UnimplementedError('openNotificationSettings() has not been implemented.');}
  Future<void> openBluetoothSettings(){  throw UnimplementedError('openBluetoothSettings() has not been implemented.');}
}
