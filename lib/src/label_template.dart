abstract class LabelElement {
  final int x;
  final int y;
  final String dataKey; // Key to map data from Map<String, dynamic>

  LabelElement({required this.x, required this.y, required this.dataKey});
}

class TextElement extends LabelElement {
  final int fontSize;
  final String? fontFamily;

  TextElement({
    required super.x,
    required super.y,
    required super.dataKey,
    this.fontSize = 24,
    this.fontFamily,
  });
}

class BarcodeElement extends LabelElement {
  final int width;
  final int height;
  final bool isCode128;

  BarcodeElement({
    required super.x,
    required super.y,
    required super.dataKey,
    this.width = 200,
    this.height = 60,
    this.isCode128 = false,
  });
}

class ImageElement extends LabelElement {
  final int width;
  final int height;

  ImageElement({
    required super.x,
    required super.y,
    required super.dataKey,
    this.width = 100,
    this.height = 100,
  });
}

class LabelTemplate {
  final int width;
  final int height;
  final List<LabelElement> elements;

  LabelTemplate({
    required this.width,
    required this.height,
    required this.elements,
  });
}
