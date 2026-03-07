# Flutter Niimbot (Pure Dart Edition)

A robust, cross-platform Flutter library designed for seamless Bluetooth Low Energy (BLE) printing with NIIMBOT thermal printers. Operating entirely in pure Dart, this package supports automatic printer model detection and offers extensive capabilities for rendering rich content like text, QR codes, barcodes, and images on over 85+ printer models.

## ✨ Key Features

- 🔍 **Smart Auto-Detection** - Intelligently identifies the connected NIIMBOT printer model and selects the appropriate print protocol.
- 📱 **Pure Dart BLE** - Connects directly to printers using pure Dart over BLE, ensuring broad multi-platform compatibility (Mobile & Web).
- 🎨 **Advanced Content Rendering**:
  - Render crisp text using Flutter Canvas.
  - Generate QR codes with adjustable error correction levels.
  - Print barcodes (supports EAN13, CODE128).
  - Print images seamlessly from local files, memory, or network URLs.
  - Draw custom pixel arrays and precise lines.
- 🖼️ **Label Preview** - Generate a PNG preview of your label layout before sending it to the printer.
- 📏 **Pixel-Perfect Layouts** - Fine-tune positioning with detailed X/Y coordinates and various alignment modes.
- 🔄 **Broad Hardware Support** - Fully compatible with popular models like B1, B21, D110, D11, and many more.

## 📦 Installation

Include the package in your `pubspec.yaml`:

```yaml
dependencies:
  flutter_niimbot: ^1.0.1
```

Then fetch the dependencies:

```bash
flutter pub get
```

## 🔧 Platform Configuration

### Android Setup

You must declare the required Bluetooth permissions in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

Ensure your `minSdkVersion` is at least 21 in `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        minSdkVersion 21
    }
}
```

### iOS Setup

Update your `ios/Runner/Info.plist` with the necessary privacy descriptions:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app requires Bluetooth access to connect with NIIMBOT printers.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app requires Bluetooth access to connect with NIIMBOT printers.</string>
```

Your `ios/Podfile` should specify a minimum iOS version of 12.0:

```ruby
platform :ios, '12.0'
```

Don't forget to install the iOS pods:

```bash
cd ios && pod install
```

## 🚀 Getting Started

### Your First Print Job

```dart
import 'package:flutter_niimbot/flutter_niimbot.dart';

// 1. Establish a connection
final client = NiimbotBluetoothClient();
await client.connect(); // Automatically scans and connects to the nearest NIIMBOT printer

// 2. Prepare the print task (auto-configured for the detected model)
client.stopHeartbeat();
client.setPacketInterval(0); // Maximize print speed
final task = client.createPrintTask(PrintOptions(
  totalPages: 1,
  density: 3, // Print density level
  labelType: 1,
));

if (task == null) {
  throw Exception('Failed to detect a compatible printer model');
}

// 3. Design your label layout
final page = PrintPage(400, 240); // Define label canvas dimensions (width x height)

page.addText('Hello, NIIMBOT!', TextOptions(
  x: 192,
  y: 100,
  fontSize: 24,
  align: HAlignment.center,
  vAlign: VAlignment.middle,
));

// 4. Execute the print command
await task.printInit();
await task.printPage(page.toEncodedImage(), 1);
await task.waitForFinished();

// Resume heartbeat monitoring after printing
client.startHeartbeat();
```

## 📖 Feature Examples

### Canvas Orientation

The `orientation` parameter allows you to effortlessly design for different label placements:

```dart
// Portrait (Default) - Ideal for standard vertical labels
final portraitPage = PrintPage(400, 240, orientation: PageOrientation.portrait);
portraitPage.addText('Item Name', TextOptions(x: 200, y: 120));

// Landscape - Ideal for printing horizontal designs on vertical paper
// Note: Dimensions (240x400) automatically flip to a 400x240 canvas and rotate content 90°
final landscapePage = PrintPage(240, 400, orientation: PageOrientation.landscape);
landscapePage.addText('Item Name', TextOptions(
  x: 200, // Coordinates remain consistent with the 400x240 layout
  y: 120,
));
```

### Rendering Text

```dart
final page = PrintPage(400, 240);

// Standard text placement
page.addText('NIIMBOT PRINTER', TextOptions(
  x: 192, y: 50,
  fontSize: 24,
  align: HAlignment.center,
  vAlign: VAlignment.middle,
));

// Bold, rotated text
page.addText('Angled Text', TextOptions(
  x: 192, y: 100,
  fontSize: 20,
  fontWeight: FontWeight.bold,
  align: HAlignment.center,
  vAlign: VAlignment.middle,
  rotate: 45, // Rotates text 45 degrees
));

// Using custom fonts
page.addText('Custom Font Styling', TextOptions(
  x: 100, y: 180,
  fontSize: 16,
  fontFamily: 'Roboto',
  align: HAlignment.left,
));
```

### QR Codes & Barcodes

```dart
// Generating a QR Code
page.addQR('https://github.com', QROptions(
  x: 192, y: 100,
  width: 150, height: 150,
  align: HAlignment.center,
  vAlign: VAlignment.middle,
  ecl: QRErrorCorrectLevel.M, // Adjust error correction (L, M, Q, H)
));

// Generating a Barcode
page.addBarcode('123456789012', BarcodeOptions(
  encoding: BarcodeEncoding.ean13, // Code128 also supported
  x: 192, y: 150,
  width: 200, height: 60,
  align: HAlignment.center,
  vAlign: VAlignment.middle,
));
```

### Printing Images (File & Network)

```dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

// From Local File
final localBytes = await File('path/to/logo.png').readAsBytes();
final localImg = img.decodeImage(localBytes)!;

page.addImageFromBuffer(ImageFromBufferOptions(
  buffer: localImg,
  x: 192, y: 100,
  width: 200, height: 150,
  align: HAlignment.center,
  vAlign: VAlignment.middle,
  threshold: 128, // Adjust grayscale conversion threshold
));

// From Network URL
final networkResponse = await http.get(Uri.parse('https://example.com/icon.png'));
final networkImg = img.decodeImage(networkResponse.bodyBytes)!;

page.addImageFromBuffer(ImageFromBufferOptions(
  buffer: networkImg,
  x: 192, y: 200,
  width: 100, height: 100,
  align: HAlignment.center,
  vAlign: VAlignment.middle,
  threshold: 128,
));
```

### Advanced Graphics (Lines & Custom Pixels)

```dart
// Drawing a line across the label
page.addLine(LineOptions(
  x: 10, y: 100,
  endX: 374, endY: 100,
  thickness: 2,
));

// Injecting custom raw pixel arrays (1=black, 0=white)
final rawPixels = [
  0,0,0,0,1,1,0,0,0,0,1,1,0,0,0,0,
  // ... pixel data ...
];

page.addPixelData(ImageOptions(
  data: rawPixels,
  imageWidth: 16, imageHeight: 11,
  x: 192, y: 100,
  width: 128, height: 88,
  align: HAlignment.center,
  vAlign: VAlignment.middle,
));
```

### Previewing Labels

```dart
final page = PrintPage(400, 240);
page.addText('Preview Mode', TextOptions(
  x: 192, y: 100,
  align: HAlignment.center, vAlign: VAlignment.middle,
));

// Extracts PNG formatted bytes representing the label
final previewBytes = await page.toPreviewImage();
// Display in your app using Image.memory(previewBytes)
```

## 🎯 Alignment Logic

The rendering engine relies on **reference point alignment**:

```dart
// Center aligning maps the text's center point perfectly to the x: 192 coordinate.
page.addText('Perfect Center', TextOptions(
  x: 192,
  y: 100,
  align: HAlignment.center,
  vAlign: VAlignment.middle,
));
```

## 🐛 Troubleshooting Guide

*   **Printer Not Found?** Ensure Bluetooth is on, location permissions are granted (Android), and the printer is powered on and ready to pair. Use `listDevices()` to debug visible BLE peripherals.
*   **Faded/Dark Prints?** Modify the `density` property (scale 1-5, default is 3) when initializing your `PrintOptions`.
*   **Distorted Images?** Make sure image widths are multiples of 8. Tweak the `threshold` parameter to improve the black & white conversion contrast.

## 📄 License

MIT

## 🙏 Acknowledgements

Architectural foundation inspired by the excellent work in [niimblue](https://github.com/MultiMote/niimblue) by MultiMote.
