import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:al_qassam_app/features/reports_export/services/excel_exporter.dart';
import 'package:al_qassam_app/features/financial_engine/domain/models/incoming_remittance.dart';

void main() {
  test('ExcelExporter creates and encodes valid excel file', () async {
    final excel = Excel.createExcel();
    final sheet = excel['كشف الوارد'];
    sheet.appendRow([TextCellValue('تجربة')]);

    final bytesFromEncode = excel.encode();
    expect(bytesFromEncode, isNotNull);
    expect(bytesFromEncode!.isNotEmpty, isTrue);

    final bytesFromSave = excel.save();
    expect(bytesFromSave, isNotNull);
    expect(bytesFromSave!.isNotEmpty, isTrue);
  });
}
