package uz.greenwhite.spp_connection_plugin

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.content.Context
import java.io.IOException
import java.util.ArrayDeque

class BluetoothDeviceManager(
    private val context: Context,
    private val bluetoothAdapter: BluetoothAdapter?
) {
    private var serialSocket: SerialSocket? = null
    private var callback: BluetoothConnectionCallback? = null

    @SuppressLint("MissingPermission")
    fun getPairedDevices(): List<BluetoothDevice> {
        return bluetoothAdapter?.bondedDevices?.filter { device ->
            device.type != BluetoothDevice.DEVICE_TYPE_LE
        }?.sortedWith { a, b ->
            BluetoothUtil.compareTo(a, b)
        } ?: emptyList()
    }

    fun connectToDevice(address: String, callback: BluetoothConnectionCallback) {
        this.callback = callback

        val device = bluetoothAdapter?.getRemoteDevice(address)
            ?: throw IOException("Bluetooth device not found")

        serialSocket = SerialSocket(context, device).apply {
            connect(object : SerialListener {
                override fun onSerialConnect() {
                    callback.onConnectionStateChanged(ConnectionState.CONNECTED.ordinal)
                }

                override fun onSerialConnectError(e: Exception) {
                    callback.onError("Connection failed: ${e.message}")
                }

                override fun onSerialRead(data: ByteArray) {
                    callback.onDataReceived(data)
                }

                override fun onSerialRead(datas: ArrayDeque<ByteArray>) {
                    for (data in datas) {
                        callback.onDataReceived(data)
                    }
                }

                override fun onSerialIoError(e: Exception) {
                    callback.onError("IO error: ${e.message}")
                    disconnect()
                }
            })
        }
    }

    fun disconnect() {
        callback?.onConnectionStateChanged(ConnectionState.DISCONNECTING.ordinal)
        serialSocket?.disconnect()
        serialSocket = null
        callback?.onConnectionStateChanged(ConnectionState.DISCONNECTED.ordinal)
    }

    @Throws(IOException::class)
    fun sendData(data: ByteArray) {
        serialSocket?.write(data) ?: throw IOException("Not connected")
    }

    fun isConnected(): Boolean {
        return serialSocket != null
    }
}
