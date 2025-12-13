import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_niimbot/flutter_niimbot.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_niimbot/image_encoder.dart';
import 'package:flutter_niimbot/print_tasks/b1_print_task.dart';
import 'package:flutter_niimbot/packets/packet_generator.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<ScanResult> _devices = [];
  String? _connectedDeviceId;
  bool _isScanning = false;
  String _log = "";
  StreamSubscription? _scanSub;

  @override
  void initState() {
    super.initState();
  }
  
  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  void _logMsg(String msg) {
    setState(() {
      _log += "$msg\n";
    });
    print(msg);
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _devices = [];
    });
    
    try {
      _scanSub = Niimbot.scanResults.listen((results) {
         setState(() {
           _devices = results;
         });
      });
      
      await Niimbot.startScan();
      _logMsg("Scanning started...");
    } catch (e) {
      _logMsg("Scan failed: $e");
    } finally {
      // Auto stop handled by timeout in lib, but we update UI
      Future.delayed(Duration(seconds: 5), () {
         if (mounted) setState(() => _isScanning = false);
      });
    }
  }

  Future<void> _connect(String deviceId) async {
    try {
      _logMsg("Connecting to $deviceId...");
      await Niimbot.connect(deviceId);
      
      // Handshake / Connect Packet
      _logMsg("Sending Connect Packet...");
      await PacketGenerator.connect(Niimbot.sendPacket);
      
      setState(() {
        _connectedDeviceId = deviceId;
      });
      _logMsg("Connected!");
      
      Niimbot.packets.listen((p) {
         // _logMsg("Rx Cmd: ${p['cmd']}");
      });
      
    } catch (e) {
      _logMsg("Connect failed: $e");
    }
  }

  Future<void> _disconnect() async {
    try {
      await Niimbot.disconnect();
      setState(() {
        _connectedDeviceId = null;
      });
      _logMsg("Disconnected");
    } catch (e) {
      _logMsg("Disconnect failed: $e");
    }
  }

  Future<void> _printTest() async {
    if (_connectedDeviceId == null) return;
    
    try {
      _logMsg("Generating image...");
      final image = img.Image(width: 384, height: 200);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      img.drawString(image, 'Flutter Blue Plus!', font: img.arial24, x: 50, y: 50, color: img.ColorRgb8(0, 0, 0));
      img.drawRect(image, x1: 10, y1: 10, x2: 370, y2: 190, color: img.ColorRgb8(0, 0, 0));
      
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
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Niimbot FBP'),
        ),
        body: Column(
          children: [
            if (_connectedDeviceId == null)
              ElevatedButton(
                onPressed: _isScanning ? null : _startScan,
                child: Text(_isScanning ? "Scanning..." : "Scan"),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Connected: $_connectedDeviceId"),
                  SizedBox(width: 10),
                  ElevatedButton(onPressed: _disconnect, child: Text("Disconnect")),
                ],
              ),
            
            Expanded(
              child: ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final d = _devices[index];
                  return ListTile(
                    title: Text(d.device.platformName.isNotEmpty ? d.device.platformName : "Unknown"),
                    subtitle: Text(d.device.remoteId.toString()),
                    onTap: () => _connect(d.device.remoteId.str),
                  );
                },
              ),
            ),
            
            if (_connectedDeviceId != null)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: ElevatedButton(
                  onPressed: _printTest,
                  style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                  child: Text("Print Test Label"),
                ),
              ),
              
            Container(
              height: 150,
              color: Colors.grey[200],
              child: SingleChildScrollView(child: Text(_log)),
            )
          ],
        ),
      ),
    );
  }
}
