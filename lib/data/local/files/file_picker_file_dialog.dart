import 'dart:typed_data';

import 'package:budget_tracker/domain/repositories/file_dialogs.dart';
import 'package:file_picker/file_picker.dart';

/// Системные диалоги выбора файла на плагине `file_picker` (ADR-0006, решение 6.5).
///
/// `saveFile` принимает байты: плагин сам записывает файл в выбранное место, а
/// вызывающий код не зависит от того, является ли выбранное место обычным путем
/// файловой системы или документом SAF.
class FilePickerFileDialog implements FileDialog {
  const FilePickerFileDialog();

  @override
  Future<Uri?> saveBytes({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
  }) => FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
    dialogTitle: dialogTitle,
  );

  @override
  Future<Uint8List?> pickBytes({String? dialogTitle}) async {
    final file = await FilePicker.pickFile(dialogTitle: dialogTitle);
    return file?.readAsBytes();
  }
}
