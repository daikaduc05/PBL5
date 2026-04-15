String formatStopwatch(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String formatSessionTimestamp(DateTime timestamp) {
  return '${_monthName(timestamp.month)} ${timestamp.day}, ${timestamp.year} - ${_formatTime(timestamp)}';
}

String formatShortDate(DateTime timestamp) {
  return '${_monthName(timestamp.month)} ${timestamp.day}, ${timestamp.year}';
}

String formatShortDateTime(DateTime timestamp) {
  return '${_monthName(timestamp.month)} ${timestamp.day} - ${_formatTime(timestamp)}';
}

String buildSessionId(DateTime timestamp) {
  final year = (timestamp.year % 100).toString().padLeft(2, '0');
  final month = timestamp.month.toString().padLeft(2, '0');
  final day = timestamp.day.toString().padLeft(2, '0');
  final hour = timestamp.hour.toString().padLeft(2, '0');
  final minute = timestamp.minute.toString().padLeft(2, '0');
  return 'PT-$year$month$day-$hour$minute';
}

String _formatTime(DateTime timestamp) {
  final hour = timestamp.hour.toString().padLeft(2, '0');
  final minute = timestamp.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _monthName(int month) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return months[month - 1];
}
