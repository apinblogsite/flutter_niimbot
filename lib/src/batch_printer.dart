import 'package:flutter_niimbot/flutter_niimbot.dart';

class NiimbotBatchPrinter {
  final NiimbotBluetoothClient client;

  NiimbotBatchPrinter(this.client);

  /// Prints a batch of pre-encoded images as a single job
  Future<void> printBatch(List<EncodedImage> images, {PrintOptions? options}) async {
    if (images.isEmpty) return;

    final opts = options ?? PrintOptions(
      totalPages: images.length,
      density: 3,
      labelType: LabelType.withGaps,
    );

    client.stopHeartbeat();
    client.setPacketInterval(0);

    final task = client.createPrintTask(opts);
    if (task == null) {
      throw Exception('Printer model not detected');
    }

    await task.printInit();

    for (final img in images) {
      await task.printPage(img, 1);
    }

    await task.waitForFinished();
    client.startHeartbeat();
  }
}
