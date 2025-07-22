package uz.greenwhite.spp_connection_plugin

import java.util.ArrayDeque

interface SerialListener {
    fun onSerialConnect()
    fun onSerialConnectError(e: Exception)
    fun onSerialRead(data: ByteArray)
    fun onSerialRead(datas: ArrayDeque<ByteArray>)
    fun onSerialIoError(e: Exception)
}