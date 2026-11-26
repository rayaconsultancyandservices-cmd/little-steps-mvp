
// CSV फाइल download करण्यासाठी (फक्त Web वर चालते).
// Android / iOS वर stub वापरला जातो, म्हणून Teacher/Parent APK build तुटत नाही.
export 'csv_download_stub.dart'
if (dart.library.js_interop) 'csv_download_web.dart';