enum BluetoothConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

extension BluetoothConnectionStateExtension on BluetoothConnectionState {
  String get displayName {
    switch (this) {
      case BluetoothConnectionState.disconnected:
        return 'Disconnected';
      case BluetoothConnectionState.connecting:
        return 'Connecting...';
      case BluetoothConnectionState.connected:
        return 'Connected';
      case BluetoothConnectionState.disconnecting:
        return 'Disconnecting...';
    }
  }

  bool get isConnected => this == BluetoothConnectionState.connected;
  bool get isConnecting => this == BluetoothConnectionState.connecting;
  bool get isDisconnected => this == BluetoothConnectionState.disconnected;
}
