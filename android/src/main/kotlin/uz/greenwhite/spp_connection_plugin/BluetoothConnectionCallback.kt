package uz.greenwhite.spp_connection_plugin
interface BluetoothConnectionCallback {
    fun onConnectionStateChanged(state: Int)
    fun onDataReceived(data: ByteArray)
    fun onError(error: String)
}