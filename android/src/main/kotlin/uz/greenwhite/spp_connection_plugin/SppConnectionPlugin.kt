package uz.greenwhite.spp_connection_plugin

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel

/** SppConnectionPlugin */
class SppConnectionPlugin: FlutterPlugin, MethodCallHandler , ActivityAware {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel

  private lateinit var methodChannel: MethodChannel
  private lateinit var connectionStateEventChannel: EventChannel
  private lateinit var dataEventChannel: EventChannel
  private lateinit var deviceListEventChannel: EventChannel

  private lateinit var context: Context
  private var activity: Activity? = null
  private var bluetoothAdapter: BluetoothAdapter? = null

  private lateinit var bluetoothDeviceManager: BluetoothDeviceManager
  private lateinit var permissionHandler: BluetoothPermissionHandler

  private var connectionStateEventSink: EventChannel.EventSink? = null
  private var dataEventSink: EventChannel.EventSink? = null
  private var deviceListEventSink: EventChannel.EventSink? = null


  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext

    // Initialize method channel
    methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_bluetooth_terminal/methods")
    methodChannel.setMethodCallHandler(this)

    // Initialize event channels
    connectionStateEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "flutter_bluetooth_terminal/connection_state")
    connectionStateEventChannel.setStreamHandler(ConnectionStateStreamHandler())

    dataEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "flutter_bluetooth_terminal/data")
    dataEventChannel.setStreamHandler(DataStreamHandler())

    deviceListEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "flutter_bluetooth_terminal/device_list")
    deviceListEventChannel.setStreamHandler(DeviceListStreamHandler())

    // Initialize Bluetooth adapter
    val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager?
    bluetoothAdapter = bluetoothManager?.adapter

    // Initialize managers
    bluetoothDeviceManager = BluetoothDeviceManager(context, bluetoothAdapter)
    permissionHandler = BluetoothPermissionHandler()
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "isBluetoothSupported" -> handleIsBluetoothSupported(result)
      "isBluetoothEnabled" -> handleIsBluetoothEnabled(result)
      "enableBluetooth" -> handleEnableBluetooth(result)
      "hasPermissions" -> handleHasPermissions(result)
      "requestPermissions" -> handleRequestPermissions(result)
      "getPairedDevices" -> handleGetPairedDevices(result)
      "connectToDevice" -> handleConnectToDevice(call, result)
      "disconnect" -> handleDisconnect(result)
      "sendData" -> handleSendData(call, result)
      "startBackgroundService" -> handleStartBackgroundService(result)
      "stopBackgroundService" -> handleStopBackgroundService(result)
      "areNotificationsEnabled" -> handleAreNotificationsEnabled(result)
      "openNotificationSettings" -> handleOpenNotificationSettings(result)
      "openBluetoothSettings" -> handleOpenBluetoothSettings(result)
      else -> result.notImplemented()
    }
  }

  private fun handleIsBluetoothSupported(result: Result) {
    val supported = context.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH)
    result.success(supported)
  }

  private fun handleIsBluetoothEnabled(result: Result) {
    val enabled = bluetoothAdapter?.isEnabled ?: false
    result.success(enabled)
  }

  private fun handleEnableBluetooth(result: Result) {
    activity?.let {
      val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
      it.startActivity(enableBtIntent)
      result.success(null)
    } ?: run {
      result.error("NO_ACTIVITY", "Activity is required to enable Bluetooth", null)
    }
  }

  private fun handleHasPermissions(result: Result) {
    activity?.let {
      val hasPermissions = permissionHandler.hasPermissions(it)
      result.success(hasPermissions)
    } ?: run {
      result.error("NO_ACTIVITY", "Activity is required to check permissions", null)
    }
  }

  private fun handleRequestPermissions(result: Result) {
    activity?.let {
      // Permission request will be handled through ActivityAware callbacks
      // This is a simplified version - in production, you'd use proper permission callbacks
      permissionHandler.requestPermissions(it) { granted ->
        result.success(granted)
      }
    } ?: run {
      result.error("NO_ACTIVITY", "Activity is required to request permissions", null)
    }
  }

  private fun handleGetPairedDevices(result: Result) {
    try {
      val devices = bluetoothDeviceManager.getPairedDevices()
      val deviceMaps = devices.map { device ->
        mapOf(
          "name" to (device.name ?: ""),
          "address" to device.address,
          "type" to device.type,
          "bonded" to (device.bondState == android.bluetooth.BluetoothDevice.BOND_BONDED)
        )
      }
      result.success(deviceMaps)
    } catch (e: SecurityException) {
      result.error("PERMISSION_DENIED", "Bluetooth permission not granted", e.message)
    } catch (e: Exception) {
      result.error("DEVICE_LIST_ERROR", "Failed to get paired devices", e.message)
    }
  }

  private fun handleConnectToDevice(call: MethodCall, result: Result) {
    val address = call.argument<String>("address")
    if (address == null) {
      result.error("INVALID_ARGUMENT", "Device address is required", null)
      return
    }

    try {
      bluetoothDeviceManager.connectToDevice(address, object : BluetoothConnectionCallback {
        override fun onConnectionStateChanged(state: Int) {
          connectionStateEventSink?.success(mapOf("state" to state))
        }

        override fun onDataReceived(data: ByteArray) {
          dataEventSink?.success(mapOf("data" to data))
        }

        override fun onError(error: String) {
          connectionStateEventSink?.error("CONNECTION_ERROR", error, null)
        }
      })
      result.success(null)
    } catch (e: Exception) {
      result.error("CONNECTION_FAILED", "Failed to connect to device", e.message)
    }
  }

  private fun handleDisconnect(result: Result) {
    try {
      bluetoothDeviceManager.disconnect()
      result.success(null)
    } catch (e: Exception) {
      result.error("DISCONNECT_FAILED", "Failed to disconnect", e.message)
    }
  }

  private fun handleSendData(call: MethodCall, result: Result) {
    val data = call.argument<ByteArray>("data")
    if (data == null) {
      result.error("INVALID_ARGUMENT", "Data is required", null)
      return
    }

    try {
      bluetoothDeviceManager.sendData(data)
      result.success(null)
    } catch (e: Exception) {
      result.error("SEND_FAILED", "Failed to send data", e.message)
    }
  }

  private fun handleStartBackgroundService(result: Result) {
    try {
      val intent = Intent(context, SerialService::class.java)
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        context.startForegroundService(intent)
      } else {
        context.startService(intent)
      }
      result.success(null)
    } catch (e: Exception) {
      result.error("SERVICE_START_FAILED", "Failed to start background service", e.message)
    }
  }

  private fun handleStopBackgroundService(result: Result) {
    try {
      val intent = Intent(context, SerialService::class.java)
      context.stopService(intent)
      result.success(null)
    } catch (e: Exception) {
      result.error("SERVICE_STOP_FAILED", "Failed to stop background service", e.message)
    }
  }

  private fun handleAreNotificationsEnabled(result: Result) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      // Check notification settings - implementation would depend on your needs
      result.success(true) // Simplified
    } else {
      result.success(true)
    }
  }

  private fun handleOpenNotificationSettings(result: Result) {
    try {
      val intent = Intent().apply {
        action = android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS
        putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, context.packageName)
      }
      activity?.startActivity(intent)
      result.success(null)
    } catch (e: Exception) {
      result.error("SETTINGS_FAILED", "Failed to open notification settings", e.message)
    }
  }

  private fun handleOpenBluetoothSettings(result: Result) {
    try {
      val intent = Intent(android.provider.Settings.ACTION_BLUETOOTH_SETTINGS)
      activity?.startActivity(intent)
      result.success(null)
    } catch (e: Exception) {
      result.error("SETTINGS_FAILED", "Failed to open Bluetooth settings", e.message)
    }
  }

  override fun onDetachedFromEngine( binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
    connectionStateEventChannel.setStreamHandler(null)
    dataEventChannel.setStreamHandler(null)
    deviceListEventChannel.setStreamHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    permissionHandler.setActivityBinding(binding)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
    permissionHandler.setActivityBinding(binding)
  }

  override fun onDetachedFromActivity() {
    activity = null
    permissionHandler.clearActivityBinding()
  }

  // Event Channel Stream Handlers
  inner class ConnectionStateStreamHandler : EventChannel.StreamHandler {
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
      connectionStateEventSink = events
    }

    override fun onCancel(arguments: Any?) {
      connectionStateEventSink = null
    }
  }

  inner class DataStreamHandler : EventChannel.StreamHandler {
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
      dataEventSink = events
    }

    override fun onCancel(arguments: Any?) {
      dataEventSink = null
    }
  }

  inner class DeviceListStreamHandler : EventChannel.StreamHandler {
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
      deviceListEventSink = events
    }

    override fun onCancel(arguments: Any?) {
      deviceListEventSink = null
    }
  }
}
