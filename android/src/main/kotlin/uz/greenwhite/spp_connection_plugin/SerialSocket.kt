package uz.greenwhite.spp_connection_plugin

import android.app.Activity
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import java.io.IOException
import java.security.InvalidParameterException
import java.util.*
import java.util.concurrent.Executors

class SerialSocket(
    private val context: Context,
    private val device: BluetoothDevice
) : Runnable {

    companion object {
        private val BLUETOOTH_SPP = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    }

    private val disconnectBroadcastReceiver: BroadcastReceiver
    private val mainHandler = Handler(Looper.getMainLooper())
    private var listener: SerialListener? = null
    private var socket: BluetoothSocket? = null
    private var connected = false

    init {
        if (context is Activity) {
            throw InvalidParameterException("expected non UI context")
        }

        disconnectBroadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                mainHandler.post {
                    listener?.onSerialIoError(IOException("background disconnect"))
                }
                disconnect()
            }
        }
    }

    fun getName(): String {
        return device.name ?: device.address
    }

    @Throws(IOException::class)
    fun connect(listener: SerialListener) {
        this.listener = listener
        ContextCompat.registerReceiver(
            context,
            disconnectBroadcastReceiver,
            IntentFilter(Constants.INTENT_ACTION_DISCONNECT),
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
        Executors.newSingleThreadExecutor().submit(this)
    }

    fun disconnect() {
        listener = null
        if (socket != null) {
            try {
                socket?.close()
            } catch (ignored: Exception) {
            }
            socket = null
        }
        try {
            context.unregisterReceiver(disconnectBroadcastReceiver)
        } catch (ignored: Exception) {
        }
    }

    @Throws(IOException::class)
    fun write(data: ByteArray) {
        if (!connected) {
            throw IOException("not connected")
        }
        socket?.outputStream?.write(data)
    }

    override fun run() {
        try {
            socket = device.createRfcommSocketToServiceRecord(BLUETOOTH_SPP)
            socket?.connect()

            // Post connection success to main thread
            mainHandler.post {
                listener?.onSerialConnect()
            }
        } catch (e: Exception) {
            // Post connection error to main thread
            mainHandler.post {
                listener?.onSerialConnectError(e)
            }
            try {
                socket?.close()
            } catch (ignored: Exception) {
            }
            socket = null
            return
        }

        connected = true
        try {
            val buffer = ByteArray(1024)
            var len: Int
            while (true) {
                len = socket?.inputStream?.read(buffer) ?: break
                val data = buffer.copyOf(len)

                // Post data received to main thread
                mainHandler.post {
                    listener?.onSerialRead(data)
                }
            }
        } catch (e: Exception) {
            connected = false

            // Post IO error to main thread
            mainHandler.post {
                listener?.onSerialIoError(e)
            }
            try {
                socket?.close()
            } catch (ignored: Exception) {
            }
            socket = null
        }
    }
}