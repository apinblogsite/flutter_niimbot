import 'dart:typed_data';
import 'package:image/image.dart';

class EncodedImage {
  final int rows;
  final int cols;
  final List<RowData> rowsData;

  EncodedImage({required this.rows, required this.cols, required this.rowsData});
}

class RowData {
  final int rowNumber;
  final int repeat;
  final String dataType; // 'pixels', 'void', 'check'
  final Uint8List? rowData;
  final int blackPixelsCount;

  RowData({
    required this.rowNumber,
    required this.repeat,
    required this.dataType,
    this.rowData,
    this.blackPixelsCount = 0,
  });
}

class ImageEncoder {
  static EncodedImage encode(Image image, {bool dither = true}) {
    // 1. Resize/Convert to B&W if needed (Assuming caller handles resizing to fit width)
    // 2. Dither
    Image processed = dither ? _ditherImage(image) : image;

    // 3. Slice into rows
    List<RowData> rows = [];
    
    // Each row is 1 pixel high.
    // Need to pack bits. 1 byte = 8 pixels.
    // 0 = white, 1 = black.
    
    int widthBytes = (processed.width + 7) ~/ 8;
    
    for (int y = 0; y < processed.height; y++) {
      Uint8List rowBytes = Uint8List(widthBytes);
      int blackCount = 0;
      
      for (int x = 0; x < processed.width; x++) {
        Pixel p = processed.getPixel(x, y);
        // Assuming grayscale/binary. If luminance < threshold -> black (1)
        if (p.r < 128) { // Simple threshold
           int byteIndex = x ~/ 8;
           int bitIndex = 7 - (x % 8);
           rowBytes[byteIndex] |= (1 << bitIndex);
           blackCount++;
        }
      }
      
      if (blackCount > 0) {
        rows.add(RowData(
          rowNumber: y,
          repeat: 1,
          dataType: 'pixels',
          rowData: rowBytes,
          blackPixelsCount: blackCount,
        ));
      } else {
         rows.add(RowData(
          rowNumber: y,
          repeat: 1,
          dataType: 'void',
        ));
      }
    }
    
    return EncodedImage(rows: processed.height, cols: processed.width, rowsData: rows);
  }

  static Image _ditherImage(Image image) {
    // Basic Floyd-Steinberg or Ordered Dither
    // For simplicity in this port, we use a threshold or relying on 'image' package quantization if available.
    // 'image' package has methods for this.
    return image; // Placeholder: caller should pass properly sized image.
  }
}
