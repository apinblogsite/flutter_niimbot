import 'dart:typed_data';
import 'abstract_client.dart';

class NiimbotSerialClient extends NiimbotAbstractClient {
  NiimbotSerialClient() {
    throw UnsupportedError('Serial port is not supported on this platform');
  }

  @override
  Future<ConnectionInfo> connect() async {
    throw UnsupportedError('Serial port is not supported on this platform');
  }

  @override
  Future<void> disconnect() async {
    throw UnsupportedError('Serial port is not supported on this platform');
  }

  @override
  bool isConnected() => false;

  @override
  Future<void> sendRaw(Uint8List data, {bool force = false}) async {
    throw UnsupportedError('Serial port is not supported on this platform');
  }

  static Future<bool> isAvailable() async => false;
}
