import 'package:flutter/material.dart';
import 'package:spp_connection_plugin/spp_connection_plugin.dart';
import 'package:spp_connection_plugin/src/bluetooth_connection_state.dart';
import 'package:spp_connection_plugin/src/bluetooth_device_model.dart';
import 'package:spp_connection_plugin/src/text_utils.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Terminal Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: DevicesScreen(),
    );
  }
}

class DevicesScreen extends StatefulWidget {
  @override
  _DevicesScreenState createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final SppConnectionPlugin _bluetooth = SppConnectionPlugin();
  List<BluetoothDeviceModel> _devices = [];
  bool _isLoading = true;
  bool _hasPermissions = false;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    try {
      // Check if Bluetooth is supported
      final isSupported = await _bluetooth.isBluetoothSupported();
      if (!isSupported) {
        _showError('Bluetooth is not supported on this device');
        return;
      }

      // Check permissions
      _hasPermissions = await _bluetooth.hasPermissions();
      if (!_hasPermissions) {
        _hasPermissions = await _bluetooth.requestPermissions();
      }

      if (_hasPermissions) {
        await _loadDevices();
      }
    } catch (e) {
      _showError('Failed to initialize Bluetooth: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await _bluetooth.getPairedDevices();
      setState(() {
        _devices = devices;
      });
    } catch (e) {
      _showError('Failed to load devices: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bluetooth Devices'),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _hasPermissions ? _loadDevices : null),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => _bluetooth.openBluetoothSettings(),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (!_hasPermissions) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Bluetooth permissions are required'),
            SizedBox(height: 16),
            ElevatedButton(onPressed: () => _initBluetooth(), child: Text('Request Permissions')),
          ],
        ),
      );
    }

    if (_devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_searching, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No paired Bluetooth devices found'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _bluetooth.openBluetoothSettings(),
              child: Text('Open Bluetooth Settings'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        return ListTile(
          leading: Icon(Icons.bluetooth),
          title: Text(device.displayName),
          subtitle: Text(device.address),
          trailing: Icon(Icons.chevron_right),
          onTap: () => _connectToDevice(device),
        );
      },
    );
  }

  void _connectToDevice(BluetoothDeviceModel device) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => TerminalScreen(device: device)));
  }
}

class TerminalScreen extends StatefulWidget {
  final BluetoothDeviceModel device;

  const TerminalScreen({Key? key, required this.device}) : super(key: key);

  @override
  _TerminalScreenState createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final SppConnectionPlugin _bluetooth = SppConnectionPlugin();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  List<String> _messages = [];
  bool _hexMode = false;
  String _newlineType = TextUtils.newlineCRLF;

  @override
  void initState() {
    super.initState();
    _connectToDevice();
    _setupListeners();
  }

  void _setupListeners() {
    // Listen to connection state changes
    _bluetooth.connectionStateStream.listen((state) {
      setState(() {
        _connectionState = state;
      });

      if (state == BluetoothConnectionState.connected) {
        _addMessage('Connected to ${widget.device.displayName}', isStatus: true);
      } else if (state == BluetoothConnectionState.disconnected) {
        _addMessage('Disconnected', isStatus: true);
      }
    });

    // Listen to incoming data
    _bluetooth.dataStream.listen((data) {
      final text = _hexMode ? TextUtils.toHexString(data) : String.fromCharCodes(data);
      _addMessage(text, isReceived: true);
    });
  }

  Future<void> _connectToDevice() async {
    try {
      setState(() {
        _connectionState = BluetoothConnectionState.connecting;
      });

      await _bluetooth.connectToDevice(widget.device.address);
    } catch (e) {
      _addMessage('Connection failed: $e', isStatus: true);
      setState(() {
        _connectionState = BluetoothConnectionState.disconnected;
      });
    }
  }

  void _addMessage(String message, {bool isReceived = false, bool isStatus = false}) {
    setState(() {
      final timestamp = DateTime.now().toString().substring(11, 19);
      String prefix = '';

      if (isStatus) {
        prefix = '[$timestamp] ';
      } else if (isReceived) {
        prefix = '[$timestamp] RX: ';
      } else {
        prefix = '[$timestamp] TX: ';
      }

      _messages.add(prefix + message);
    });

    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    final text = _textController.text;
    if (text.isEmpty || !_connectionState.isConnected) return;

    try {
      if (_hexMode) {
        if (!TextUtils.isValidHexString(text)) {
          _showError('Invalid hex string format');
          return;
        }
        await _bluetooth.sendHex(text);
      } else {
        await _bluetooth.sendText(text);
      }

      _addMessage(text, isReceived: false);
      _textController.clear();
    } catch (e) {
      _showError('Failed to send message: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _showNewlineDialog() {
    final newlineOptions = {
      TextUtils.newlineCR: 'CR (\\r)',
      TextUtils.newlineLF: 'LF (\\n)',
      TextUtils.newlineCRLF: 'CRLF (\\r\\n)',
    };

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Select Newline'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  newlineOptions.entries.map((entry) {
                    return RadioListTile<String>(
                      title: Text(entry.value),
                      value: entry.key,
                      groupValue: _newlineType,
                      onChanged: (value) {
                        setState(() {
                          _newlineType = value!;
                          _bluetooth.setNewlineType(value);
                        });
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
            ),
          ),
    );
  }

  @override
  void dispose() {
    _bluetooth.disconnect();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.displayName),
        actions: [
          IconButton(
            icon: Icon(Icons.clear),
            onPressed: () {
              setState(() {
                _messages.clear();
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'hex':
                  setState(() {
                    _hexMode = !_hexMode;
                    _bluetooth.setHexMode(_hexMode);
                  });
                  break;
                case 'newline':
                  _showNewlineDialog();
                  break;
                case 'disconnect':
                  _bluetooth.disconnect();
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'hex',
                    child: Row(
                      children: [
                        Icon(Icons.code, color: _hexMode ? Colors.blue : null),
                        SizedBox(width: 8),
                        Text('Hex Mode'),
                        if (_hexMode) Icon(Icons.check, color: Colors.blue),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'newline',
                    child: Row(
                      children: [Icon(Icons.keyboard_return), SizedBox(width: 8), Text('Newline')],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'disconnect',
                    child: Row(
                      children: [
                        Icon(Icons.bluetooth_disabled),
                        SizedBox(width: 8),
                        Text('Disconnect'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status indicator
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(8),
            color:
                _connectionState.isConnected
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
            child: Text(
              _connectionState.displayName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _connectionState.isConnected ? Colors.green[800] : Colors.red[800],
              ),
            ),
          ),

          // Messages area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isStatus =
                    message.contains('] ') && !message.contains('TX:') && !message.contains('RX:');
                final isReceived = message.contains('RX:');

                return Container(
                  margin: EdgeInsets.only(bottom: 4),
                  child: Text(
                    message,
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 12,
                      color:
                          isStatus
                              ? Colors.orange[800]
                              : isReceived
                              ? Colors.blue[800]
                              : Colors.green[800],
                    ),
                  ),
                );
              },
            ),
          ),

          // Input area
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText:
                          _hexMode ? 'Enter hex data (e.g., 48 65 6C 6C 6F)' : 'Enter message',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    enabled: _connectionState.isConnected,
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _connectionState.isConnected ? _sendMessage : null,
                  child: Text('Send'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
