import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_niimbot/flutter_niimbot.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_niimbot/image_encoder.dart';
import 'package:flutter_niimbot/print_tasks/b1_print_task.dart';
import 'package:flutter_niimbot/packets/packet_generator.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr/qr.dart';

class PrinterController extends ChangeNotifier {
  List<ScanResult> _devices = [];
  String? _connectedDeviceId;
  bool _isScanning = false;
  String _log = "";
  StreamSubscription? _scanSub;
  StreamSubscription? _packetSub;

  List<ScanResult> get devices => _devices;
  String? get connectedDeviceId => _connectedDeviceId;
  bool get isScanning => _isScanning;
  String get log => _log;
  bool get isConnected => _connectedDeviceId != null;

  PrinterController() {
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    if (statuses[Permission.bluetoothScan]?.isDenied ?? false) {
      _logMsg("Bluetooth Scan denied");
    }
  }

  void _logMsg(String msg) {
    _log += "$msg\n";
    print(msg);
    notifyListeners();
  }

  Future<void> startScan() async {
    if (_isScanning) return;

    _isScanning = true;
    _devices = [];
    notifyListeners();

    try {
      await _scanSub?.cancel();

      _scanSub = Niimbot.scanResults.listen((results) {
        _devices = results;
        notifyListeners();
      });

      await Niimbot.startScan();
      _logMsg("Scanning started...");

      // Auto stop scanning after 10 seconds to save battery/resources
      Future.delayed(const Duration(seconds: 10), () {
        if (_isScanning) {
          stopScan();
        }
      });

    } catch (e) {
      _logMsg("Scan failed: $e");
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
     _isScanning = false;
     notifyListeners();
  }

  Future<void> connect(String deviceId) async {
    try {
      _logMsg("Connecting to $deviceId...");
      _isScanning = false;
      notifyListeners();

      await Niimbot.connect(deviceId);

      _logMsg("Sending Connect Packet...");
      await PacketGenerator.connect(Niimbot.sendPacket);

      _connectedDeviceId = deviceId;
      _logMsg("Connected!");

       _packetSub = Niimbot.packets.listen((p) {
        // _logMsg("Rx Cmd: ${p['cmd']}");
      });

      notifyListeners();

    } catch (e) {
      _logMsg("Connect failed: $e");
      _connectedDeviceId = null;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    try {
      await Niimbot.disconnect();
      _connectedDeviceId = null;
      _packetSub?.cancel();
      _logMsg("Disconnected");
      notifyListeners();
    } catch (e) {
      _logMsg("Disconnect failed: $e");
    }
  }

  Future<void> printLabel(String id, String keterangan) async {
    if (_connectedDeviceId == null) {
      _logMsg("Not connected to any printer");
      return;
    }

    try {
      _logMsg("Generating label for ID: $id");

      final int width = 384;
      final int height = 240;

      final image = img.Image(width: width, height: height);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));

      // 1. Generate QR Code
      final qrCode = QrCode(4, QrErrorCorrectLevel.L);
      qrCode.addData(id);

      final qrImage = QrImage(qrCode);

      final int qrSize = 150;
      final int moduleSize = (qrSize / qrImage.moduleCount).floor();
      final int qrX = 10;
      final int qrY = (height - (qrImage.moduleCount * moduleSize)) ~/ 2;

      for (int x = 0; x < qrImage.moduleCount; x++) {
        for (int y = 0; y < qrImage.moduleCount; y++) {
          if (qrImage.isDark(y, x)) {
             img.fillRect(
               image,
               x1: qrX + x * moduleSize,
               y1: qrY + y * moduleSize,
               x2: qrX + (x + 1) * moduleSize,
               y2: qrY + (y + 1) * moduleSize,
               color: img.ColorRgb8(0, 0, 0)
             );
          }
        }
      }

      // 2. Draw Text
      final int textX = qrX + (qrImage.moduleCount * moduleSize) + 20;
      int textY = 50;

      // Draw ID
      img.drawString(
        image,
        "ID: $id",
        font: img.arial24,
        x: textX,
        y: textY,
        color: img.ColorRgb8(0, 0, 0)
      );

      textY += 40;

      // Draw Keterangan
      // Simple word wrap
      List<String> words = keterangan.split(' ');
      String line = "";
      for (var word in words) {
        if ((line + word).length * 12 > (width - textX)) { // rough char width estimation
          img.drawString(
            image,
            line,
            font: img.arial24,
            x: textX,
            y: textY,
            color: img.ColorRgb8(0, 0, 0)
          );
          line = "";
          textY += 30;
        }
        line += "$word ";
      }
      if (line.isNotEmpty) {
        img.drawString(
            image,
            line,
            font: img.arial24,
            x: textX,
            y: textY,
            color: img.ColorRgb8(0, 0, 0)
          );
      }

      _logMsg("Encoding...");
      final encoded = ImageEncoder.encode(image);

      _logMsg("Printing...");
      final task = B1PrintTask();
      await task.print(encoded, 1);
      _logMsg("Print Done!");

    } catch (e) {
      _logMsg("Print error: $e");
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _packetSub?.cancel();
    super.dispose();
  }
}
