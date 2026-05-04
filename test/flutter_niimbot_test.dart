import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_niimbot/flutter_niimbot.dart';

void main() {
  test('PrintPage orientation sets correct width and height', () {
    final portrait = PrintPage(400, 240, PageOrientation.portrait);
    expect(portrait.width, 400);
    expect(portrait.height, 240);

    final landscape = PrintPage(240, 400, PageOrientation.landscape);
    expect(landscape.width, 400); // Expect swapped values
    expect(landscape.height, 240);
  });
}
