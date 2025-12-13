package com.example.flutter_niimbot

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class FlutterNiimbotPlugin(private val context: Context) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothGatt: BluetoothGatt? = null
    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())

    private var targetServiceUuid: UUID? = null
    private var targetCharUuid: UUID? = null

    companion object {
        private const val TAG = "FlutterNiimbot"
    }

    init {
        val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager.adapter
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scan" -> startScan(result)
            "connect" -> {
                val deviceId = call.argument<String>("deviceId")
                if (deviceId != null) {
                    connect(deviceId, result)
                } else {
                    result.error("INVALID_ARGUMENT", "Device ID is required", null)
                }
            }
            "disconnect" -> disconnect(result)
            "sendPacket" -> {
                val cmd = call.argument<Int>("cmd")
                val payload = call.argument<ByteArray>("payload")
                if (cmd != null && payload != null) {
                    sendPacket(cmd, payload, result)
                } else {
                    result.error("INVALID_ARGUMENT", "cmd and payload are required", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun startScan(result: MethodChannel.Result) {
        if (bluetoothAdapter == null || !bluetoothAdapter!!.isEnabled) {
            result.error("BLUETOOTH_OFF", "Bluetooth is not enabled", null)
            return
        }

        val scanner = bluetoothAdapter!!.bluetoothLeScanner
        val devices = mutableListOf<Map<String, String>>()
        val scannedAddresses = mutableSetOf<String>()

        val scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, scanResult: ScanResult?) {
                scanResult?.device?.let { device ->
                    if (device.name != null && !scannedAddresses.contains(device.address)) {
                        scannedAddresses.add(device.address)
                        devices.add(mapOf("name" to device.name, "id" to device.address))
                    }
                }
            }
            
            override fun onScanFailed(errorCode: Int) {
                Log.e(TAG, "Scan failed: $errorCode")
            }
        }

        scanner.startScan(scanCallback)
        
        // Stop scanning after 5 seconds and return results
        handler.postDelayed({
            scanner.stopScan(scanCallback)
            result.success(devices)
        }, 5000)
    }

    private fun connect(deviceId: String, result: MethodChannel.Result) {
        val device = bluetoothAdapter?.getRemoteDevice(deviceId)
        if (device == null) {
            result.error("DEVICE_NOT_FOUND", "Device not found", null)
            return
        }

        bluetoothGatt = device.connectGatt(context, false, object : BluetoothGattCallback() {
            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    gatt.discoverServices()
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    runOnMain {
                        eventSink?.success(mapOf("type" to "disconnected"))
                    }
                    targetServiceUuid = null
                    targetCharUuid = null
                }
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    // Dynamic discovery logic: Find char with Notify + WriteWithoutResponse
                    for (service in gatt.services) {
                        if (service.uuid.toString().length < 5) continue // Skip invalid UUIDs

                        for (characteristic in service.characteristics) {
                            val props = characteristic.properties
                            val hasNotify = (props and BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0
                            val hasWriteNoResp = (props and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE) != 0

                            if (hasNotify && hasWriteNoResp) {
                                targetServiceUuid = service.uuid
                                targetCharUuid = characteristic.uuid
                                Log.d(TAG, "Found suitable characteristic: $targetCharUuid in service $targetServiceUuid")
                                
                                // Enable notifications
                                gatt.setCharacteristicNotification(characteristic, true)
                                // We might need to write descriptor for notifications to work on some devices
                                val descriptor = characteristic.getDescriptor(UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"))
                                if (descriptor != null) {
                                     descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                                     gatt.writeDescriptor(descriptor)
                                }

                                runOnMain { result.success(true) }
                                return
                            }
                        }
                    }
                    runOnMain { result.error("NO_CHARACTERISTIC", "No suitable characteristic found", null) }
                    gatt.disconnect()
                } else {
                    runOnMain { result.error("DISCOVERY_FAILED", "Service discovery failed", null) }
                }
            }

            override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
                val data = characteristic.value
                runOnMain {
                    eventSink?.success(mapOf("type" to "packet", "data" to data))
                }
            }
        })
    }

    private fun disconnect(result: MethodChannel.Result) {
        bluetoothGatt?.disconnect()
        bluetoothGatt?.close()
        bluetoothGatt = null
        result.success(true)
    }

    private fun sendPacket(cmd: Int, payload: ByteArray, result: MethodChannel.Result) {
        if (bluetoothGatt == null || targetServiceUuid == null || targetCharUuid == null) {
            result.error("NOT_CONNECTED", "Not connected to printer", null)
            return
        }

        val packet = buildPacket(cmd, payload)
        val service = bluetoothGatt!!.getService(targetServiceUuid)
        val char = service?.getCharacteristic(targetCharUuid)

        if (char != null) {
            char.value = packet
            char.writeType = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
            val success = bluetoothGatt!!.writeCharacteristic(char)
            if (success) {
                result.success(null)
            } else {
                result.error("WRITE_FAILED", "Failed to write characteristic", null)
            }
        } else {
            result.error("CHAR_NOT_FOUND", "Characteristic not found", null)
        }
    }

    private fun buildPacket(cmd: Int, payload: ByteArray): ByteArray {
        val head = byteArrayOf(0x55, 0x55)
        val tail = byteArrayOf(0xAA.toByte(), 0xAA.toByte())
        
        // Calculate Checksum
        // checksum ^= cmd
        // checksum ^= len
        // checksum ^= each byte of data
        
        var checksum = cmd xor payload.size
        for (b in payload) {
            checksum = checksum xor (b.toInt() and 0xFF)
        }
        
        // 0x55, 0x55, CMD, LEN, DATA..., CHECKSUM, 0xAA, 0xAA
        val packetSize = 2 + 1 + 1 + payload.size + 1 + 2
        val buffer = java.nio.ByteBuffer.allocate(packetSize)
        
        buffer.put(head)
        buffer.put(cmd.toByte())
        buffer.put(payload.size.toByte())
        buffer.put(payload)
        buffer.put(checksum.toByte())
        buffer.put(tail)
        
        val arr = buffer.array()

        // Special case for Connect (0xC1 or 193) -> Prefix with 0x03?
        // Reference: NiimbotPacket.ts: 
        // if (this._command === RequestCommandId.Connect) { return new Uint8Array([3, ...arr]); }
        if (cmd == 0xC1) {
            val prefixed = ByteArray(arr.size + 1)
            prefixed[0] = 0x03
            System.arraycopy(arr, 0, prefixed, 1, arr.size)
            return prefixed
        }

        return arr
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun runOnMain(runnable: () -> Unit) {
        handler.post(runnable)
    }
}
