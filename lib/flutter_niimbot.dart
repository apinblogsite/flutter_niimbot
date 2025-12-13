import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class Niimbot {
  static const MethodChannel _channel = MethodChannel('flutter_niimbot');
  static const EventChannel _eventChannel = EventChannel('flutter_niimbot/events');

  static StreamSubscription? _subscription;
  static final StreamController<Map<String, dynamic>> _eventController = StreamController.broadcast();

  static Future<List<Map<String, String>>> scan() async {
    final List<dynamic> devices = await _channel.invokeMethod('scan');
    return devices.map((e) => Map<String, String>.from(e)).toList();
  }

  static Future<void> connect(String deviceId) async {
    await _channel.invokeMethod('connect', {'deviceId': deviceId});
    _listenToEvents();
  }

  static Future<void> disconnect() async {
    await _channel.invokeMethod('disconnect');
    _subscription?.cancel();
  }

  static Future<void> sendPacket(int cmd, Uint8List payload) async {
    await _channel.invokeMethod('sendPacket', {'cmd': cmd, 'payload': payload});
  }

  static Stream<Map<String, dynamic>> get events => _eventController.stream;

  static void _listenToEvents() {
    _subscription?.cancel();
    _subscription = _eventChannel.receiveBroadcastStream().listen((event) {
      _eventController.add(Map<String, dynamic>.from(event));
    }, onError: (error) {
      print("Niimbot Event Error: $error");
    });
  }
}
