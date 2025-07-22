package uz.greenwhite.spp_connection_plugin

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice

object BluetoothUtil {
    @SuppressLint("MissingPermission")
    fun compareTo(a: BluetoothDevice, b: BluetoothDevice): Int {
        val aValid = a.name != null && a.name.isNotEmpty()
        val bValid = b.name != null && b.name.isNotEmpty()

        return when {
            aValid && bValid -> {
                val ret = a.name.compareTo(b.name)
                if (ret != 0) ret else a.address.compareTo(b.address)
            }
            aValid -> -1
            bValid -> 1
            else -> a.address.compareTo(b.address)
        }
    }
}
