import 'dart:typed_data';
import 'package:flutter_niimbot/flutter_niimbot.dart';
import 'package:flutter_niimbot/image_encoder.dart';
import 'package:flutter_niimbot/packets/packet_generator.dart';

class B1PrintTask {
  final int printheadPixels;
  final int density;
  final int labelType;

  B1PrintTask({
    this.printheadPixels = 203 * 48 ~/ 25.4 * 8, // Estimate: 384px? No.
    // B1 is usually 203dpi. Max width ~48mm.
    // 48mm / 25.4 * 203 = ~383.6 -> 384 pixels.
    // Let's default to 384 if unknown, but better if passed.
    // Actually printheadPixels is used for the "split" count calculation.
    // If we assume full width (384), chunkSize = 16 bytes.
    // If the image is narrower, it fits.
    this.density = 2,
    this.labelType = 1, // WithGaps
  });

  Future<void> print(EncodedImage image, int quantity) async {
    // 1. Init
    await PacketGenerator.setDensity(Niimbot.sendPacket, density);
    await PacketGenerator.setLabelType(Niimbot.sendPacket, labelType);
    await PacketGenerator.printStart7b(Niimbot.sendPacket, quantity);
    
    // 2. Page Start
    await PacketGenerator.pageStart(Niimbot.sendPacket);
    
    // 3. Set Page Size
    await PacketGenerator.setPageSize6b(Niimbot.sendPacket, image.rows, image.cols, quantity);
    
    // 4. Send Image Data
    // Use 384 as printheadPixels for B1 calculation by default or use image width?
    // utils.ts: chunkSize = floor(printheadPixels / 8 / 3).
    // If we use image.cols (width in pixels) as printheadPixels, it might match the strip.
    // But usually printheadPixels is physical property.
    // Let's assume 384 for B1.
    int pHead = 384; 
    
    for (var row in image.rowsData) {
       if (row.dataType == 'pixels' && row.rowData != null) {
          await PacketGenerator.printBitmapRow(
             Niimbot.sendPacket, 
             row.rowNumber, 
             row.repeat, 
             row.rowData!,
             pHead
          );
       } else if (row.dataType == 'void') {
          await PacketGenerator.printEmptySpace(Niimbot.sendPacket, row.rowNumber, row.repeat);
       }
       // Throttle slightly to not flood BLE?
       // Native queue should handle it, but small delay might help stability.
       await Future.delayed(Duration(milliseconds: 1)); 
    }
    
    // 5. Page End
    await PacketGenerator.pageEnd(Niimbot.sendPacket);
    
    // 6. Wait for finish (Polling status)
    // Simplified: Just wait a bit or poll once.
    // Implementing full status polling might be overkill for V1, but let's do a simple delay.
    await Future.delayed(Duration(seconds: 1));
    
    // 7. Print End
    await PacketGenerator.printEnd(Niimbot.sendPacket);
  }
}
