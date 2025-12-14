# Flutter Niimbot Plugin

A Flutter plugin to connect and print on **Niimbot thermal label printers** via Bluetooth (BLE).
Currently optimized for **Niimbot B1**, but architecture allows supporting other models (D11, D110, etc.).

## Features

*   **Connect**: Scan and connect to Niimbot printers (dynamic UUID discovery).
*   **Protocol**: Hybrid architecture (Dart Logic + Native Framing) for robust communication.
*   **Print Image**: Print any image (PNG/JPG converted to bitmap).
*   **Print Text**: Simple text printing helper.
*   **Print QR/Barcode**: Built-in support for generating and printing QR Codes and Barcodes.
*   **Status**: Monitor connection state and print job status.

## Getting Started

1.  Add dependency to `pubspec.yaml`:
    ```yaml
    dependencies:
      flutter_niimbot:
        git:
          url: https://github.com/apinblosite/flutter_niimbot.git
    ```

2.  **Android Permissions**:
    Add the following to your `android/app/src/main/AndroidManifest.xml`:
    ```xml
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    ```
    And request these permissions at runtime using `permission_handler`.

3.  **iOS Permissions**:
    Add `NSBluetoothAlwaysUsageDescription` to `Info.plist`.

## Usage

### Connect

```dart
import 'package:flutter_niimbot/flutter_niimbot.dart';

// 1. Scan
Niimbot.startScan();
Niimbot.scanResults.listen((results) {
  // Show list
});

// 2. Connect
await Niimbot.connect(deviceId);
```

### Print

```dart
// Print Text
await Niimbot.printText("Hello World", fontSize: 30);

// Print QR Code
await Niimbot.printQRCode("https://flutter.dev");

// Print Barcode
await Niimbot.printBarcode("1234567890");

// Print Custom Image
final image = ...; // Load using 'image' package
await Niimbot.printImage(image);
```

### Status

```dart
// Listen to printing state
Niimbot.printingState.listen((state) {
  print("Print State: $state"); // idle, inProgress, success, error
});

// Get Printer Status (Battery, etc) - Experimental
await Niimbot.requestPrinterStatus();
Niimbot.printerStatus.listen((status) {
   print("Battery: ${status.chargeLevel}");
});
```

## Architecture

This plugin uses a **Hybrid Architecture**:
*   **Dart**: Handles BLE I/O (via `flutter_blue_plus`), Image Processing, and Print Command orchestration (State Machine).
*   **Native (Kotlin/Swift)**: Handles low-level Protocol Framing (Header, Checksum, Escaping) to ensure performance and correctness.

## Contributing

Pull requests are welcome! Please ensure you test on actual hardware if possible.
