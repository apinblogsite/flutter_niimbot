import 'package:pluto_grid/pluto_grid.dart';

class PlutoAdapter {
  static List<Map<String, dynamic>> plutoRowsToMap(List<PlutoRow> rows) {
    if (rows.isEmpty) return [];

    return rows.map((row) {
      final Map<String, dynamic> rowData = {};
      row.cells.forEach((key, cell) {
        rowData[key] = cell.value;
      });
      return rowData;
    }).toList();
  }
}
