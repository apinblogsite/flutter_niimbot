import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:webserial/webserial.dart';
import 'abstract_client.dart';
import '../events.dart';
import '../packets/payloads.dart';

extension type JSReadableStreamDefaultReadResult._(JSObject _) implements JSObject {
  external bool get done;
  external JSObject? get value; // Workaround for JSUint8Array toDart issue
}

extension ReadableStreamDefaultReaderExt on ReadableStreamDefaultReader {
  external JSPromise<JSReadableStreamDefaultReadResult> read();
  external void releaseLock();
}

@JS()
extension type WritableStreamDefaultWriterExt(JSObject _) implements WritableStreamDefaultWriter {
  @JS('write')
  external JSPromise<JSAny?> _write(JSUint8Array data);

  Future<void> writeData(JSUint8Array data) async {
    _write(data);
  }

  external void releaseLock();
}

class NiimbotSerialClient extends NiimbotAbstractClient {
  JSSerialPort? _port;
  bool _isConnected = false;

  @override
  Future<ConnectionInfo> connect() async {
    if (_isConnected) {
      return ConnectionInfo(
        deviceName: "WebSerial",
        result: ConnectResult.connected,
      );
    }

    try {
      final port = await requestWebSerialPort(null);
      if (port == null) throw Exception("No serial port selected");

      // Default to 115200 for Niimbot serial
      await port.open(JSSerialOptions(
        baudRate: 115200,
        dataBits: 8,
        stopBits: 1,
        parity: 'none',
        bufferSize: 255,
        flowControl: 'none'
      )).toDart;

      _port = port;
      _isConnected = true;

      _listenToPort(port);

      await initialNegotiate();
      await fetchPrinterInfo();

      final connectionInfo = ConnectionInfo(
        deviceName: "WebSerial",
        result: info.connectResult ?? ConnectResult.disconnect,
      );
      emit(ClientEvents.connected, connectionInfo);
      return connectionInfo;
    } catch (e) {
      _isConnected = false;
      rethrow;
    }
  }

  void _listenToPort(JSSerialPort port) async {
    try {
      if (port.readable == null) return;
      final reader = port.readable!.getReader() as ReadableStreamDefaultReader;
      while (_isConnected) {
        final promise = reader.read();
        final result = await promise.toDart;
        if (result.done) {
          reader.releaseLock();
          break;
        }
        final data = result.value;
        if (data != null) {
          final jsArray = data as JSUint8Array;
          processRawPacket(jsArray.toDart);
        }
      }
    } catch (e) {
      if (debug) print('Serial read error: $e');
    } finally {
      await disconnect();
    }
  }

  @override
  Future<void> disconnect() async {
    if (!_isConnected || _port == null) return;
    try {
      stopHeartbeat();
      _isConnected = false;

      // Close port
      await _port!.close().toDart;
      emit(ClientEvents.disconnected, null);
    } catch (e) {
      // ignore
    } finally {
      _port = null;
    }
  }

  @override
  bool isConnected() => _isConnected;

  @override
  Future<void> sendRaw(Uint8List data, {bool force = false}) async {
    if (!_isConnected || _port == null) throw Exception("Not connected");
    try {
      final writer = _port!.writable!.getWriter() as WritableStreamDefaultWriterExt;
      await writer.writeData(data.toJS);
      writer.releaseLock();
    } catch (e) {
      rethrow;
    }
  }

  static Future<bool> isAvailable() async {
    try {
      // Accessing global 'serial' throws if not available
      serial;
      return true;
    } catch (e) {
      return false;
    }
  }
}
