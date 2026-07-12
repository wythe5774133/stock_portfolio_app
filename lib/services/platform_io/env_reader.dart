// 環境變數讀取的條件匯出：原生用 dart:io，網頁用 stub。

export 'env_reader_io.dart' if (dart.library.js_interop) 'env_reader_web.dart';
