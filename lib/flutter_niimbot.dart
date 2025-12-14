import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_niimbot/packets/commands.dart';
import 'package:flutter_niimbot/packets/packet_generator.dart';
import 'package:flutter_niimbot/print_tasks/b1_print_task.dart';
import 'package:flutter_niimbot/image_encoder.dart';
import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';
import 'package:barcode_image/barcode_image.dart';

/// Enum representing the state of the printing process.
enum PrintingState {
  idle,
  inProgress,
  success,
  error,
}

/// Represents the status of the printer.
class PrinterStatus {
  final int chargeLevel;
  // Add other fields as we map them (paper status, cover, etc)
  
  PrinterStatus({required this.chargeLevel});
  
  @override
  String toString() => 'PrinterStatus(chargeLevel: $chargeLevel)';
}

/// Main class for interacting with Niimbot printers.
class Niimbot {
  static const MethodChannel _channel = MethodChannel('flutter_niimbot');
  
  static BluetoothDevice? _connectedDevice;
  static BluetoothCharacteristic? _characteristic;
  static StreamSubscription? _notifySubscription;
  
  static final StreamController<Map<String, dynamic>> _packetController = StreamController.broadcast();
  static final StreamController<PrintingState> _printingStateController = StreamController.broadcast();
  static final StreamController<PrinterStatus> _printerStatusController = StreamController.broadcast();

  /// Stream of received packets from the printer.
  static Stream<Map<String, dynamic>> get packets => _packetController.stream;
  
  /// Stream of printing state (idle, inProgress, success, error).
  static Stream<PrintingState> get printingState => _printingStateController.stream;

  /// Stream of printer status updates.
  static Stream<PrinterStatus> get printerStatus => _printerStatusController.stream;

  /// Starts scanning for BLE devices.
  static Future<void> startScan() async {
     await FlutterBluePlus.startScan(timeout: Duration(seconds: 5));
  }
  
  /// Stream of scan results.
  static Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
  
  /// Stops scanning.
  static Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  /// Connects to a printer by Device ID.
  /// 
  /// Throws an exception if connection fails or characteristic is not found.
  static Future<void> connect(String deviceId) async {
    try {
      final device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));
      
      // Auto-connect false to allow error handling
      await device.connect(autoConnect: false);
      _connectedDevice = device;
      
      await _discoverCharacteristic(device);
      
      // Listen to connection state to handle unexpected disconnects
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _disconnectCleanup();
        }
      });
      
    } catch (e) {
      // Ensure cleanup if connection sequence fails
      await disconnect();
      rethrow;
    }
  }

  static Future<void> _discoverCharacteristic(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    
    // Find service/char with Notify + WriteNoResponse
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
                   final p = Map<String, dynamic>.from(parsed);
                   _packetController.add(p);
                   _handlePacket(p);
                }
             } catch (e) {
               // Ignore malformed packets
             }
          });
          
          return;
        }
      }
    }
    throw StateError("No suitable Niimbot characteristic found on device.");
  }

  static void _handlePacket(Map<String, dynamic> packet) {
     final cmd = packet['cmd'] as int;
     final payload = packet['payload'] as Uint8List;
     
     // Handle Status Responses
     // ResponseCommandId.In_PrinterStatusData = 0xB5
     // ResponseCommandId.In_PrinterInfoChargeLevel = 0x4A
     
     if (cmd == ResponseCommandId.inPrinterStatusData) { // 0xB5
         // Payload format: 1 byte?
         // niimbluelib: printerStatusData returns just the payload.
         // We need to decode it.
     }
     if (cmd == ResponseCommandId.inPrinterInfoChargeLevel) { // 0x4A
         if (payload.isNotEmpty) {
             _printerStatusController.add(PrinterStatus(chargeLevel: payload[0]));
         }
     }
  }

  /// Disconnects from the printer.
  static Future<void> disconnect() async {
    await _connectedDevice?.disconnect();
    _disconnectCleanup();
  }
  
  static void _disconnectCleanup() {
    _notifySubscription?.cancel();
    _notifySubscription = null;
    _connectedDevice = null;
    _characteristic = null;
    _printingStateController.add(PrintingState.idle);
  }

  /// Sends a raw command packet to the printer.
  static Future<void> sendPacket(int cmd, Uint8List payload) async {
    if (_characteristic == null) throw StateError("Not connected to printer");
    
    final Uint8List framed = await _channel.invokeMethod('buildPacket', {
      'cmd': cmd,
      'payload': payload
    });
    
    try {
      await _characteristic!.write(framed, withoutResponse: true);
    } catch (e) {
      throw StateError("Failed to write to characteristic: $e");
    }
  }
  
  /// Requests the printer status (battery level).
  static Future<void> requestPrinterStatus() async {
      // 0x40 (PrinterInfo) with type 3 (ChargeLevel)? 
      // PacketGenerator.getPrinterInfo(PrinterInfoType.ChargeLevel)
      // or PrinterStatusData (0xA5).
      
      // Let's implement a specific one for battery level in PacketGenerator?
      // PacketGenerator.ts uses 0x40 for PrinterInfo.
      // 1 = Density, 2 = Speed, 3 = LabelType, ... 0x0A = ChargeLevel?
      // Need to check commands.ts in niimbluelib.
      // But we have PacketGenerator.getPrinterStatusData (0xA5).
      
      await PacketGenerator.getPrinterStatusData(sendPacket);
  }
  
  // --- High Level API ---
  
  /// Prints an image (must be pre-processed or simple bitmap).
  static Future<void> printImage(img.Image image, {int quantity = 1}) async {
      await _printGeneric(() async {
          final encoded = ImageEncoder.encode(image);
          final task = B1PrintTask();
          await task.print(encoded, quantity);
      });
  }
  
  /// Helper to wrap print jobs with state management
  static Future<void> _printGeneric(Future<void> Function() action) async {
    if (_printingStateController.hasListener) {
      _printingStateController.add(PrintingState.inProgress);
    }
    
    try {
      await action();
      if (_printingStateController.hasListener) {
        _printingStateController.add(PrintingState.success);
      }
    } catch (e) {
      if (_printingStateController.hasListener) {
        _printingStateController.add(PrintingState.error);
      }
      rethrow;
    } finally {
      // Optional: reset to idle after short delay? 
      // Or let UI handle it. 
      // Usually "Success" is a terminal state for that job.
    }
  }
  
  /// Prints text by rendering it to an image.
  /// 
  /// Note: This is a basic implementation. For advanced styling, render a Widget to image in your app.
  static Future<void> printText(String text, {int fontSize = 24}) async {
    // Basic implementation using 'image' package font
    final image = img.Image(width: 384, height: fontSize + 20);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    img.drawString(image, text, font: img.arial24, x: 10, y: 10, color: img.ColorRgb8(0,0,0));
    
    await printImage(image);
  }
  
  /// Prints a QR Code.
  static Future<void> printQRCode(String data, {int size = 200}) async {
    final qr = QrCode(4, QrErrorCorrectLevel.L)..addData(data);
    final qrImage = QrImage(qr);
    
    final image = img.Image(width: 384, height: 384); // Fit width
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    
    // Manual QR drawing or use package helper
    // Since 'qr' package just gives logic, we map it to 'image'.
    // Or use 'barcode_image' package which supports QR too?
    
    // Let's use barcode_image for everything if possible
    drawBarcode(image, Barcode.qrCode(), data, x: (384-size)~/2, y: 10, width: size, height: size);
    
    await printImage(image);
  }
  
  /// Prints a Barcode (Code128, EAN, etc).
  static Future<void> printBarcode(String data, {int width = 300, int height = 100, bool drawText = true}) async {
     final image = img.Image(width: 384, height: height + 50);
     img.fill(image, color: img.ColorRgb8(255, 255, 255));
     
     drawBarcode(image, Barcode.code128(), data, x: (384-width)~/2, y: 10, width: width, height: height, font: drawText ? img.arial24 : null);
     
     await printImage(image);
  }
}
