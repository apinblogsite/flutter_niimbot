import 'dart:typed_data';
import 'package:flutter_niimbot/packets/commands.dart';

class PacketGenerator {
  static Uint8List u16ToBytes(int value) {
    final bd = ByteData(2);
    bd.setUint16(0, value, Endian.big);
    return bd.buffer.asUint8List();
  }

  static Future<void> connect(Function(int, Uint8List) send) async {
    await send(RequestCommandId.connect, Uint8List.fromList([1]));
  }

  static Future<void> setDensity(Function(int, Uint8List) send, int density) async {
    await send(RequestCommandId.setDensity, Uint8List.fromList([density]));
  }

  static Future<void> setLabelType(Function(int, Uint8List) send, int labelType) async {
    await send(RequestCommandId.setLabelType, Uint8List.fromList([labelType]));
  }

  static Future<void> printStart7b(Function(int, Uint8List) send, int totalPages) async {
    final bytes = <int>[];
    bytes.addAll(u16ToBytes(totalPages));
    bytes.addAll([0, 0, 0, 0, 0]);
    await send(RequestCommandId.printStart, Uint8List.fromList(bytes));
  }

  static Future<void> pageStart(Function(int, Uint8List) send) async {
    await send(RequestCommandId.pageStart, Uint8List.fromList([1]));
  }

  static Future<void> pageEnd(Function(int, Uint8List) send) async {
    await send(RequestCommandId.pageEnd, Uint8List.fromList([1]));
  }

  static Future<void> printEnd(Function(int, Uint8List) send) async {
    await send(RequestCommandId.printEnd, Uint8List.fromList([1]));
  }

  static Future<void> setPageSize6b(Function(int, Uint8List) send, int rows, int cols, int copies) async {
    final bytes = <int>[];
    bytes.addAll(u16ToBytes(rows));
    bytes.addAll(u16ToBytes(cols));
    bytes.addAll(u16ToBytes(copies));
    await send(RequestCommandId.setPageSize, Uint8List.fromList(bytes));
  }
  
  static Future<void> printEmptySpace(Function(int, Uint8List) send, int pos, int repeats) async {
    final bytes = <int>[];
    bytes.addAll(u16ToBytes(pos));
    bytes.add(repeats);
    await send(RequestCommandId.printEmptyRow, Uint8List.fromList(bytes));
  }

  static Future<void> printBitmapRow(Function(int, Uint8List) send, int pos, int repeats, Uint8List data, int printheadPixels) async {
    final parts = countPixelsForBitmapPacket(data, printheadPixels);
    
    final bytes = <int>[];
    bytes.addAll(u16ToBytes(pos));
    bytes.addAll(parts); // 3 bytes
    bytes.add(repeats);
    bytes.addAll(data);
    await send(RequestCommandId.printBitmapRow, Uint8List.fromList(bytes));
  }

  static List<int> countPixelsForBitmapPacket(Uint8List buf, int printheadPixels) {
     // Simplified logic based on Utils.ts
     // mode = auto -> split or total
     // printheadPixels (e.g. 384)
     
     int chunkSize = (printheadPixels / 8 / 3).floor();
     bool split = buf.length <= chunkSize * 3;
     
     if (split) {
       List<int> parts = [0, 0, 0];
       for (int i = 0; i < buf.length; i++) {
         int value = buf[i];
         int chunkIdx = (i / chunkSize).floor();
         
         for (int bit = 0; bit < 8; bit++) {
           if ((value & (1 << bit)) != 0) {
             if (chunkIdx < 3) {
                parts[chunkIdx]++;
             }
           }
         }
       }
       // Clamp to 255 to avoid overflow issues (warn in TS)
       for(int k=0;k<3;k++) if(parts[k] > 255) parts[k] = 255;
       return parts;
     } else {
       // Total mode
       int total = 0;
       for (int b in buf) {
         for (int bit = 0; bit < 8; bit++) {
           if ((b & (1 << bit)) != 0) total++;
         }
       }
       final tBytes = u16ToBytes(total);
       return [0, tBytes[0], tBytes[1]];
     }
  }
}
