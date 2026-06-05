/// Conditional import:
/// - Trên web (dart.library.html available): dùng web stub (placeholder)
/// - Trên native (dart.library.io available): dùng dart:io TCP Socket implementation
export 'pi_preview_socket_view_web.dart'
    if (dart.library.io) 'pi_preview_socket_view_native.dart';
