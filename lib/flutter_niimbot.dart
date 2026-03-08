/// Niim Blue Flutter Library
///
/// A Flutter library for Bluetooth LE printing with NIIMBOT thermal printers.
library flutter_niimbot;

// Packets
export 'src/packets/packet.dart';
export 'src/packets/packet_generator.dart';
export 'src/packets/packet_parser.dart';
export 'src/packets/commands.dart';
export 'src/packets/dto.dart';
export 'src/packets/payloads.dart';
export 'src/packets/abstraction.dart';
export 'src/packets/data_reader.dart';

// Client
export 'src/client/index.dart';

// Utilities
export 'src/utils.dart';
export 'src/printer_models.dart';
export 'src/image_encoder.dart';
export 'src/events.dart';
export 'src/utils/barcode.dart';

// Print tasks
export 'src/print_tasks/index.dart';

// Print page (fabric-object)
export 'src/print_page.dart';

// High Level API
export 'src/batch_printer.dart';
export 'src/label_template.dart';
export 'src/label_renderer.dart';
export 'src/firestore_loader.dart';
export 'src/pluto_adapter.dart';

import 'package:flutter_niimbot/src/client/index.dart';
import 'package:flutter_niimbot/src/batch_printer.dart';
import 'package:flutter_niimbot/src/label_template.dart';
import 'package:flutter_niimbot/src/label_renderer.dart';
import 'package:flutter_niimbot/src/firestore_loader.dart';
import 'package:flutter_niimbot/src/pluto_adapter.dart';
import 'package:flutter_niimbot/src/print_tasks/index.dart';
import 'package:flutter_niimbot/src/print_page.dart';
import 'package:pluto_grid/pluto_grid.dart';

extension NiimbotBatchExtensions on NiimbotBluetoothClient {
  /// Batch print multiple pre-rendered label pages
  Future<void> printBatchLabels(List<EncodedImage> images, {PrintOptions? options}) async {
    final batchPrinter = NiimbotBatchPrinter(this);
    await batchPrinter.printBatch(images, options: options);
  }

  /// Batch print using a custom data-to-template renderer
  Future<void> printBatchData(List<Map<String, dynamic>> dataRows, LabelTemplate template, {PrintOptions? options}) async {
    final List<EncodedImage> encodedImages = [];
    for (var data in dataRows) {
      encodedImages.add(await LabelRenderer.renderLabel(data, template));
    }
    if (encodedImages.isEmpty) return;
    await printBatchLabels(encodedImages, options: options);
  }

  /// Batch print labels dynamically loaded from a Firestore collection
  Future<void> printBatchFromFirestore({
    required String collection,
    required LabelTemplate template,
    PrintOptions? options,
  }) async {
    final dataRows = await FirestoreLoader.loadCollection(collection);
    await printBatchData(dataRows, template, options: options);
  }

  /// Batch print selected rows from a PlutoGrid UI
  Future<void> printFromPlutoGrid(
    List<PlutoRow> rows,
    LabelTemplate template, {
    PrintOptions? options,
  }) async {
    final dataRows = PlutoAdapter.plutoRowsToMap(rows);
    await printBatchData(dataRows, template, options: options);
  }
}
