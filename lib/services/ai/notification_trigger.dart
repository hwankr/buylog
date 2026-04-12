enum NotificationTrigger { none, d7, d3, d1, d0 }

NotificationTrigger checkNotificationTrigger({
	required int dDay
}) {
	if (dDay == 7)	return NotificationTrigger.d7;
	if (dDay == 3)	return NotificationTrigger.d3;
	if (dDay == 1)	return NotificationTrigger.d1;
	if (dDay == 0)	return NotificationTrigger.d0;
	return NotificationTrigger.none;
}