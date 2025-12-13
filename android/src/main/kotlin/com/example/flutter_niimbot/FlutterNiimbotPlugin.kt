package com.example.flutter_niimbot

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.embedding.engine.plugins.FlutterPlugin
import java.nio.ByteBuffer
import java.nio.ByteOrder

/** FlutterNiimbotPlugin */
class FlutterNiimbotPlugin: FlutterPlugin, MethodCallHandler {
  private lateinit var channel : MethodChannel

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_niimbot")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "buildPacket" -> {
        val cmd = call.argument<Int>("cmd")
        val payload = call.argument<ByteArray>("payload")
        if (cmd != null && payload != null) {
          result.success(buildPacket(cmd, payload))
        } else {
          result.error("INVALID_ARGUMENT", "cmd and payload required", null)
        }
      }
      "parsePacket" -> {
        val data = call.argument<ByteArray>("data")
        if (data != null) {
          try {
            val parsed = parsePacket(data)
            result.success(parsed)
          } catch (e: Exception) {
            result.error("PARSE_ERROR", e.message, null)
          }
        } else {
          result.error("INVALID_ARGUMENT", "data required", null)
        }
      }
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  private fun buildPacket(cmd: Int, payload: ByteArray): ByteArray {
    val head = byteArrayOf(0x55, 0x55)
    val tail = byteArrayOf(0xAA.toByte(), 0xAA.toByte())
    
    // Checksum: XOR (cmd, len, data...)
    var checksum = cmd xor payload.size
    for (b in payload) {
        checksum = checksum xor (b.toInt() and 0xFF)
    }
    
    // 0x55, 0x55, CMD, LEN, DATA..., CHECKSUM, 0xAA, 0xAA
    val packetSize = 2 + 1 + 1 + payload.size + 1 + 2
    val buffer = ByteBuffer.allocate(packetSize)
    
    buffer.put(head)
    buffer.put(cmd.toByte())
    buffer.put(payload.size.toByte())
    buffer.put(payload)
    buffer.put(checksum.toByte())
    buffer.put(tail)
    
    val arr = buffer.array()

    // Special case for Connect (0xC1) -> Prefix with 0x03
    if (cmd == 0xC1) {
        val prefixed = ByteArray(arr.size + 1)
        prefixed[0] = 0x03
        System.arraycopy(arr, 0, prefixed, 1, arr.size)
        return prefixed
    }

    return arr
  }

  private fun parsePacket(data: ByteArray): Map<String, Any> {
    // Basic validation
    // Header: 55 55
    // Tail: AA AA
    // Min size: 2(H) + 1(Cmd) + 1(Len) + 0(Data) + 1(CS) + 2(T) = 7
    
    if (data.size < 7) throw Exception("Packet too short")
    
    if (data[0] != 0x55.toByte() || data[1] != 0x55.toByte()) {
        throw Exception("Invalid Header")
    }
    
    if (data[data.size - 2] != 0xAA.toByte() || data[data.size - 1] != 0xAA.toByte()) {
        throw Exception("Invalid Tail")
    }
    
    val cmd = data[2].toInt() and 0xFF
    val len = data[3].toInt() and 0xFF
    
    // Verify length
    if (data.size != 7 + len) {
         throw Exception("Invalid Length field (Expected ${7+len}, got ${data.size})")
    }
    
    val payload = data.copyOfRange(4, 4 + len)
    val receivedChecksum = data[4 + len].toInt() and 0xFF
    
    // Verify checksum
    var checksum = cmd xor len
    for (b in payload) {
        checksum = checksum xor (b.toInt() and 0xFF)
    }
    
    if (checksum != receivedChecksum) {
        throw Exception("Invalid Checksum")
    }
    
    return mapOf(
        "cmd" to cmd,
        "payload" to payload
    )
  }
}
