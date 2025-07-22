package uz.greenwhite.spp_connection_plugin

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.*
import androidx.annotation.RequiresApi
import androidx.core.app.NotificationCompat
import java.io.IOException
import java.util.*

class SerialService : Service(), SerialListener {

    inner class SerialBinder : Binder() {
        fun getService(): SerialService = this@SerialService
    }

    private enum class QueueType { Connect, ConnectError, Read, IoError }

    private class QueueItem(val type: QueueType, val e: Exception? = null, var datas: ArrayDeque<ByteArray>? = null) {
        constructor(type: QueueType, datas: ArrayDeque<ByteArray>) : this(type, null, datas)
        constructor(type: QueueType, e: Exception) : this(type, e, null)

        init {
            if (type == QueueType.Read) {
                datas = ArrayDeque()
            }
        }

        fun add(data: ByteArray) {
            datas?.add(data)
        }
    }

    private val mainLooper = Handler(Looper.getMainLooper())
    private val binder = SerialBinder()
    private val queue1 = ArrayDeque<QueueItem>()
    private val queue2 = ArrayDeque<QueueItem>()
    private val lastRead = QueueItem(QueueType.Read)

    private var socket: SerialSocket? = null
    private var listener: SerialListener? = null
    private var connected = false

    override fun onDestroy() {
        cancelNotification()
        disconnect()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder {
        return binder
    }

    @Throws(IOException::class)
    fun connect(socket: SerialSocket) {
        socket.connect(this)
        this.socket = socket
        connected = true
    }

    fun disconnect() {
        connected = false
        cancelNotification()
        socket?.disconnect()
        socket = null
    }

    @Throws(IOException::class)
    fun write(data: ByteArray) {
        if (!connected) {
            throw IOException("not connected")
        }
        socket?.write(data)
    }

    fun attach(listener: SerialListener) {
        if (Looper.getMainLooper().thread != Thread.currentThread()) {
            throw IllegalArgumentException("not in main thread")
        }

        initNotification()
        cancelNotification()

        synchronized(this) {
            this.listener = listener
        }

        // Process queued items
        for (item in queue1) {
            processQueueItem(item, listener)
        }
        for (item in queue2) {
            processQueueItem(item, listener)
        }

        queue1.clear()
        queue2.clear()
    }

    fun detach() {
        if (connected) {
            createNotification()
        }
        listener = null
    }

    private fun processQueueItem(item: QueueItem, listener: SerialListener) {
        when (item.type) {
            QueueType.Connect -> listener.onSerialConnect()
            QueueType.ConnectError -> listener.onSerialConnectError(item.e!!)
            QueueType.Read -> listener.onSerialRead(item.datas!!)
            QueueType.IoError -> listener.onSerialIoError(item.e!!)
        }
    }

    private fun initNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nc = NotificationChannel(
                Constants.NOTIFICATION_CHANNEL,
                "Background service",
                NotificationManager.IMPORTANCE_LOW
            )
            nc.setShowBadge(false)
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(nc)
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    fun areNotificationsEnabled(): Boolean {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val nc = nm.getNotificationChannel(Constants.NOTIFICATION_CHANNEL)
        return nm.areNotificationsEnabled() && nc != null && nc.importance > NotificationManager.IMPORTANCE_NONE
    }

    private fun createNotification() {
        val disconnectIntent = Intent().apply {
            setPackage(packageName)
            action = Constants.INTENT_ACTION_DISCONNECT
        }

        val restartIntent = Intent().apply {
            setClassName(this@SerialService, "com.yourpackage.flutter_bluetooth_terminal.MainActivity")
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }

        val disconnectPendingIntent = PendingIntent.getBroadcast(this, 1, disconnectIntent, flags)
        val restartPendingIntent = PendingIntent.getActivity(this, 1, restartIntent, flags)

        val builder = NotificationCompat.Builder(this, Constants.NOTIFICATION_CHANNEL)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Bluetooth Terminal")
            .setContentText("Connected to ${socket?.getName() ?: "Unknown Device"}")
            .setContentIntent(restartPendingIntent)
            .setOngoing(true)
            .addAction(
                NotificationCompat.Action(
                    android.R.drawable.ic_menu_close_clear_cancel,
                    "Disconnect",
                    disconnectPendingIntent
                )
            )

        val notification = builder.build()
        startForeground(Constants.NOTIFY_MANAGER_START_FOREGROUND_SERVICE, notification)
    }

    private fun cancelNotification() {
        stopForeground(true)
    }

    // SerialListener implementation
    override fun onSerialConnect() {
        if (connected) {
            synchronized(this) {
                if (listener != null) {
                    mainLooper.post {
                        listener?.onSerialConnect() ?: run {
                            queue1.add(QueueItem(QueueType.Connect))
                        }
                    }
                } else {
                    queue2.add(QueueItem(QueueType.Connect))
                }
            }
        }
    }

    override fun onSerialConnectError(e: Exception) {
        if (connected) {
            synchronized(this) {
                if (listener != null) {
                    mainLooper.post {
                        listener?.onSerialConnectError(e) ?: run {
                            queue1.add(QueueItem(QueueType.ConnectError, e))
                            disconnect()
                        }
                    }
                } else {
                    queue2.add(QueueItem(QueueType.ConnectError, e))
                    disconnect()
                }
            }
        }
    }

    override fun onSerialRead(datas: ArrayDeque<ByteArray>) {
        throw UnsupportedOperationException()
    }

    override fun onSerialRead(data: ByteArray) {
        if (connected) {
            synchronized(this) {
                if (listener != null) {
                    val first: Boolean
                    synchronized(lastRead) {
                        first = lastRead.datas?.isEmpty() ?: true
                        lastRead.add(data)
                    }

                    if (first) {
                        mainLooper.post {
                            val datas: ArrayDeque<ByteArray>
                            synchronized(lastRead) {
                                datas = lastRead.datas!!
                                lastRead.datas = ArrayDeque()
                            }
                            listener?.onSerialRead(datas) ?: run {
                                queue1.add(QueueItem(QueueType.Read, datas))
                            }
                        }
                    }
                } else {
                    if (queue2.isEmpty() || queue2.last.type != QueueType.Read) {
                        queue2.add(QueueItem(QueueType.Read))
                    }
                    queue2.last.add(data)
                }
            }
        }
    }

    override fun onSerialIoError(e: Exception) {
        if (connected) {
            synchronized(this) {
                if (listener != null) {
                    mainLooper.post {
                        listener?.onSerialIoError(e) ?: run {
                            queue1.add(QueueItem(QueueType.IoError, e))
                            disconnect()
                        }
                    }
                } else {
                    queue2.add(QueueItem(QueueType.IoError, e))
                    disconnect()
                }
            }
        }
    }
}
