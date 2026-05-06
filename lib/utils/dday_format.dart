String formatDdayLabel(int daysRemaining) {
  if (daysRemaining < 0) return 'D+${daysRemaining.abs()}';
  if (daysRemaining == 0) return 'D-Day';
  return 'D-$daysRemaining';
}

String formatDdayCaption(int daysRemaining) {
  if (daysRemaining < 0) return '교체 지남';
  if (daysRemaining == 0) return '오늘 교체';
  return '교체까지';
}
