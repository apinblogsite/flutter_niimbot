import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_niimbot/flutter_niimbot.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class PrinterController extends ChangeNotifier {
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _connectedDevice;
  final NiimbotBluetoothClient _client = NiimbotBluetoothClient();
  bool _isScanning = false;
  String _log = "";

  List<BluetoothDevice> get devices => _devices;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isScanning => _isScanning;
  String get log => _log;
  bool get isConnected => _connectedDevice != null && _client.isConnected();

  PrinterController() {
    _client.on(ClientEvents.disconnected).listen((_) {
      _connectedDevice = null;
      _logMsg("Disconnected");
      notifyListeners();
    });
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
      _logMsg("Scanning started...");
      _devices = await NiimbotBluetoothClient.listDevices(
          timeout: const Duration(seconds: 10));
      _logMsg("Found ${_devices.length} devices.");
    } catch (e) {
      _logMsg("Scan failed: $e");
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    try {
      _logMsg("Connecting to ${device.platformName}...");
      _client.setDevice(device);
      final info = await _client.connect();

      if (info.result == ConnectResult.connected) {
        _connectedDevice = device;
        _logMsg("Connected!");
      } else {
        _logMsg("Connection refused or failed.");
      }
      notifyListeners();
    } catch (e) {
      _logMsg("Connect failed: $e");
      _connectedDevice = null;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    try {
      await _client.disconnect();
    } catch (e) {
      _logMsg("Disconnect failed: $e");
    }
  }

  Future<void> printLabel(String id, String keterangan) async {
    if (!isConnected) {
      _logMsg("Not connected to any printer");
      return;
    }

    try {
      _logMsg("Generating label for ID: $id");

      _client.stopHeartbeat();
      _client.setPacketInterval(0); // Fast printing

      final task = _client.createPrintTask(PrintOptions(
        totalPages: 1,
        density: 3,
        labelType: LabelType.withGaps,
      ));

      if (task == null) {
        throw Exception('Printer model not detected');
      }

      final page = PrintPage(400, 240); // width x height in pixels

      // Draw Text ID
      page.addText(
          'ID: $id',
          TextOptions(
            x: 10,
            y: 30,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ));

      // Draw QR Code
      page.addQR(
          id,
          QROptions(
            x: 10,
            y: 80,
            width: 140,
            height: 140,
            ecl: QRErrorCorrection.medium,
          ));

      // Draw Keterangan (Simple Word Wrap emulation for Canvas)
      page.addText(
          keterangan,
          TextOptions(
            x: 160,
            y: 100,
            fontSize: 24,
          ));

      _logMsg("Printing...");
      await task.printInit();
      await task.printPage(page.toEncodedImage(), 1);
      await task.waitForFinished();
      _logMsg("Print Done!");

      _client.startHeartbeat();
    } catch (e) {
      _logMsg("Print error: $e");
      _client.startHeartbeat(); // Recover heartbeat on error
    }
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }
}
