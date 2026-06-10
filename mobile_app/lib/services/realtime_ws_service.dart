import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/result_models.dart';
import '../config/backend_config.dart';
import 'api_service.dart';

class RealtimeWsService {
  WebSocketChannel? _channel;
  StreamController<FrameResultDetail>? _controller;

  Stream<FrameResultDetail> subscribe(String sessionId) {
    _controller?.close();
    _channel?.sink.close();

    _controller = StreamController<FrameResultDetail>.broadcast();
    
    _connect(sessionId);

    return _controller!.stream;
  }

  Future<void> _connect(String sessionId) async {
    try {
      final apiService = ApiService();
      final settings = await apiService.getSettings();
      
      var host = settings.serverAddress.trim();
      if (host.isEmpty) {
        host = BackendConfig.defaultServerAddress;
      }
      
      // Parse host into WS URL
      if (!host.startsWith('http')) {
        host = 'http://$host';
      }
      final uri = Uri.parse(host);
      final wsHost = uri.host;
      final wsPort = uri.port > 0 ? uri.port : 8002;
      
      final wsUrl = Uri.parse('ws://$wsHost:$wsPort/ws/realtime/$sessionId');
      
      _channel = WebSocketChannel.connect(wsUrl);
      
      _channel!.stream.listen(
        (message) {
          try {
            final jsonMap = jsonDecode(message);
            final detail = FrameResultDetail.fromJson(sessionId, 0, jsonMap);
            _controller?.add(detail);
          } catch (e) {
            print('Error parsing realtime WS message: $e');
          }
        },
        onError: (error) {
          print('Realtime WS Error: $error');
          // Auto-reconnect can be implemented here if needed
        },
        onDone: () {
          print('Realtime WS Closed');
        },
      );
    } catch (e) {
      print('Error connecting to Realtime WS: $e');
      _controller?.addError(e);
    }
  }

  void disconnect() {
    _controller?.close();
    _controller = null;
    _channel?.sink.close();
    _channel = null;
  }
}
