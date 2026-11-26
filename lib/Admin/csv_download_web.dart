import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// CSV browser मधून खरी `.csv` फाइल म्हणून download करतो.
/// सुरुवातीला UTF-8 BOM जोडतो, म्हणजे Excel मध्ये मराठी नावं नीट दिसतात.
bool downloadCsvFile(String fileName, String content) {
  try {
    final bytes = utf8.encode('\uFEFF$content');
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);
    final a = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = fileName
      ..style.display = 'none';
    web.document.body!.append(a);
    a.click();
    a.remove();
    web.URL.revokeObjectURL(url);
    return true;
  } catch (_) {
    return false;
  }
}