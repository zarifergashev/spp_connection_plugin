A comprehensive Flutter plugin for Bluetooth Serial Port Profile (SPP) communication with full terminal functionality.

## Features

- **Device Management**: Scan and connect to paired Bluetooth devices
- **Serial Communication**: Send and receive data over Bluetooth SPP
- **Background Service**: Maintain connection when app is backgrounded
- **Hex Mode**: Support for hexadecimal data transmission
- **Newline Handling**: Various newline format support (CR, LF, CRLF)
- **Permission Management**: Runtime permission handling for Android 12+
- **Real-time Streaming**: Event-based data streaming
- **Error Handling**: Comprehensive error reporting and handling

## Platform Support

| Platform | Support |
|----------|---------|
| Android  | ✅ Full |
| iOS      | ⚠️ Basic |

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  spp_connection_plugin: ^0.0.9
```

## Android Setup

Add the following permissions to your `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Bluetooth permissions -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_REMOTE_MESSAGING" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE" />

<!-- Bluetooth permissions for older Android versions -->
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>

<!-- Bluetooth permissions for Android 12+ -->
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
```

## Usage

### Basic Implementation

```dart
import 'package:spp_connection_plugin/spp_connection_plugin.dart';

class BluetoothExample extends StatefulWidget {
  @override
  _BluetoothExampleState createState() => _BluetoothExampleState();
}

class _BluetoothExampleState extends State<BluetoothExample> {
  final SppConnectionPlugin _bluetooth = SppConnectionPlugin();
  
  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }
  
  Future<void> _initBluetooth() async {
    // Check permissions
    bool hasPermissions = await _bluetooth.hasPermissions();
    if (!hasPermissions) {
      hasPermissions = await _bluetooth.requestPermissions();
    }
    
    if (hasPermissions) {
      // Get paired devices
      final devices = await _bluetooth.getPairedDevices();
      // Connect to a device
      await _bluetooth.connectToDevice(devices.first.address);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<BluetoothConnectionState>(
        stream: _bluetooth.connectionStateStream,
        builder: (context, snapshot) {
          final state = snapshot.data ?? BluetoothConnectionState.disconnected;
          return Center(
            child: Text('Connection: ${state.displayName}'),
          );
        },
      ),
    );
  }
}
```

### Sending and Receiving Data

```dart
// Listen to incoming data
_bluetooth.dataStream.listen((data) {
  final text = String.fromCharCodes(data);
  print('Received: $text');
});

// Send text data
await _bluetooth.sendText('Hello World');

// Send hex data
await _bluetooth.sendHex('48 65 6C 6C 6F'); // "Hello" in hex

// Send raw bytes
final data = Uint8List.fromList([0x48, 0x65, 0x6C, 0x6C, 0x6F]);
await _bluetooth.sendData(data);
```

### Configuration Options

```dart
// Enable hex mode
_bluetooth.setHexMode(true);

// Set newline type
_bluetooth.setNewlineType(TextUtils.newlineCRLF);

// Start background service
await _bluetooth.startBackgroundService();
```

## API Reference

### Main Class: SppConnectionPlugin

#### Device Management
- `Future<bool> isBluetoothSupported()`
- `Future<bool> isBluetoothEnabled()`
- `Future<void> enableBluetooth()`
- `Future<List<BluetoothDeviceModel>> getPairedDevices()`

#### Connection Management
- `Future<void> connectToDevice(String address)`
- `Future<void> disconnect()`
- `BluetoothConnectionState get connectionState`
- `Stream<BluetoothConnectionState> get connectionStateStream`

#### Data Transmission
- `Future<void> sendData(Uint8List data)`
- `Future<void> sendText(String text)`
- `Future<void> sendHex(String hexString)`
- `Stream<Uint8List> get dataStream`

#### Permission Management
- `Future<bool> hasPermissions()`
- `Future<bool> requestPermissions()`

#### Settings
- `void setHexMode(bool enabled)`
- `void setNewlineType(String newline)`
- `Future<void> startBackgroundService()`
- `Future<void> stopBackgroundService()`

### Models

#### BluetoothDeviceModel
```dart
class BluetoothDeviceModel {
  final String name;
  final String address;
  final int type;
  final bool bonded;
  String get displayName; // Returns name if available, otherwise address
}
```

#### BluetoothConnectionState
```dart
enum BluetoothConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}
```

### Utilities

#### TextUtils
- `static Uint8List fromHexString(String hexString)`
- `static String toHexString(Uint8List bytes)`
- `static String toCaretString(String input, {bool keepNewline = true})`
- `static bool isValidHexString(String hexString)`

## Example App

The plugin includes a comprehensive example app demonstrating all features:

1. Device listing and selection
2. Terminal interface with real-time communication
3. Hex mode support
4. Connection status monitoring
5. Settings and configuration options

Run the example:

```bash
cd example
flutter run
```

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure all required permissions are declared and granted
2. **Connection Failed**: Check if device is paired and within range
3. **Data Not Received**: Verify the correct SPP UUID and data format

### Android 12+ Considerations

Android 12 introduced new Bluetooth permissions. The plugin automatically handles the transition between old and new permission models.

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests to our repository.

## License

This project is licensed under the MIT License - see the LICENSE file for details.