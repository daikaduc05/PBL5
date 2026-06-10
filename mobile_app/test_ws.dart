import 'dart:io';

void main() async {
  try {
    final wsUrl = Uri.parse('ws://172.20.10.5:8002/ws/realtime/test');
    print('Connecting to $wsUrl');
    final socket = await WebSocket.connect(wsUrl.toString());
    print('Connected!');
    socket.listen(
      (data) => print('Data: $data'),
      onError: (err) => print('Error: $err'),
      onDone: () => print('Done: ${socket.closeCode} ${socket.closeReason}'),
    );
  } catch (e) {
    print('Exception: $e');
  }
}
