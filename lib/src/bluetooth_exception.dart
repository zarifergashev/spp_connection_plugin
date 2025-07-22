/// Custom exception for Bluetooth operations
class BluetoothException implements Exception {
  final String message;

  const BluetoothException(this.message);

  @override
  String toString() => 'BluetoothException: $message';
}