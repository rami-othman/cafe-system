export 'file_handoff_types.dart';
export 'file_handoff_stub.dart'
    if (dart.library.io) 'file_handoff_io.dart'
    if (dart.library.js_interop) 'file_handoff_web.dart';
