import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class Niimbot {
  static const MethodChannel _channel = MethodChannel('flutter_niimbot');
  
  static BluetoothDevice? _connectedDevice;
  static BluetoothCharacteristic? _characteristic;
  static StreamSubscription? _notifySubscription;
  
  static final StreamController<Map<String, dynamic>> _packetController = StreamController.broadcast();

  static Stream<Map<String, dynamic>> get packets => _packetController.stream;

  static Future<void> startScan() async {
     await FlutterBluePlus.startScan(timeout: Duration(seconds: 5));
  }
  
  static Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
  
  static Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  static Future<void> connect(String deviceId) async {
    // 1. Find device
    // Since we can't get device by ID directly in FBP without scanning or previous knowledge,
    // we assume the user has a ScanResult or we scan briefly.
    // For API simplicity, let's assume we scan or use a known list.
    // But `connect(String id)` implies we might need to recreate the object.
    
    final device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));
    
    // 2. Connect
    await device.connect(autoConnect: false);
    _connectedDevice = device;
    
    // 3. Discover Services & Characteristic
    await _discoverCharacteristic(device);
    
    // 4. Send Connect Command (Handshake)
    // await _sendConnect(); // Let caller do this or do it here?
    // niimbluelib does initial negotiate.
    // We'll leave it to the task logic or user to call connect() packet.
  }

  static Future<void> _discoverCharacteristic(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    
    for (var service in services) {
      if (service.uuid.toString().length < 5) continue;
      
      for (var c in service.characteristics) {
        if (c.properties.notify && c.properties.writeWithoutResponse) {
          _characteristic = c;
          
          await c.setNotifyValue(true);
          _notifySubscription = c.onValueReceived.listen((value) async {
             try {
                final parsed = await _channel.invokeMethod('parsePacket', {'data': Uint8List.fromList(value)});
                if (parsed != null) {
                   _packetController.add(Map<String, dynamic>.from(parsed));
                }
             } catch (e) {
               // print("Packet parse error: $e");
               // Ignore invalid packets or noise
             }
          });
          
          return;
        }
      }
    }
    throw Exception("No suitable characteristic found");
  }

  static Future<void> disconnect() async {
    _notifySubscription?.cancel();
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
    _characteristic = null;
  }

  static Future<void> sendPacket(int cmd, Uint8List payload) async {
    if (_characteristic == null) throw Exception("Not connected");
    
    final Uint8List framed = await _channel.invokeMethod('buildPacket', {
      'cmd': cmd,
      'payload': payload
    });
    
    await _characteristic!.write(framed, withoutResponse: true);
  }
}
