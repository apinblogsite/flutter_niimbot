import 'dart:typed_data';

import 'package:flutter_niimbot/flutter_niimbot.dart';

class LabelRenderer {
  /// Render a label layout mapping data fields to template components
  static Future<EncodedImage> renderLabel(Map<String, dynamic> data, LabelTemplate template) async {
    final page = PrintPage(template.width, template.height);

    for (var element in template.elements) {
      final value = data[element.dataKey];
      if (value == null) continue;

      final strValue = value.toString();

      if (element is TextElement) {
        await page.addText(strValue, TextOptions(
          x: element.x,
          y: element.y,
          fontSize: element.fontSize,
          fontFamily: element.fontFamily,
        ));
      } else if (element is BarcodeElement) {
        page.addBarcode(strValue, BarcodeOptions(
          x: element.x,
          y: element.y,
          width: element.width,
          height: element.height,
          encoding: element.isCode128 ? BarcodeEncoding.code128 : BarcodeEncoding.ean13,
        ));
      } else if (element is ImageElement) {
        if (value is List<int>) {
          // addImageFromBuffer expects raw bytes for img.decodeImage or decoded bytes?
          // Looking at addImageFromBuffer implementation:
          // final image = img.decodeImage(options.buffer!);
          // So it expects the raw file bytes (like PNG/JPG file bytes)
          page.addImageFromBuffer(ImageFromBufferOptions(
            buffer: Uint8List.fromList(value),
            x: element.x,
            y: element.y,
            width: element.width,
            height: element.height,
          ));
        }
      }
    }

    return page.toEncodedImage();
  }
}
