class BluetoothConstants {
  // Bluetooth UUIDs
  static const String sppUuid = '00001101-0000-1000-8000-00805F9B34FB';

  // Connection timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration disconnectionTimeout = Duration(seconds: 10);

  // Buffer sizes
  static const int readBufferSize = 1024;
  static const int maxQueueSize = 100;

  // Notification IDs
  static const int foregroundServiceNotificationId = 1001;

  // Intent actions
  static const String intentActionDisconnect = 'flutter_bluetooth_terminal.Disconnect';
  static const String notificationChannel = 'flutter_bluetooth_terminal.Channel';

  // Error codes
  static const String errorBluetoothNotSupported = 'BLUETOOTH_NOT_SUPPORTED';
  static const String errorBluetoothNotEnabled = 'BLUETOOTH_NOT_ENABLED';
  static const String errorPermissionDenied = 'PERMISSION_DENIED';
  static const String errorConnectionFailed = 'CONNECTION_FAILED';
  static const String errorNotConnected = 'NOT_CONNECTED';
  static const String errorInvalidData = 'INVALID_DATA';

  // Device types
  static const int deviceTypeClassic = 1;
  static const int deviceTypeLe = 2;
  static const int deviceTypeDual = 3;
}
