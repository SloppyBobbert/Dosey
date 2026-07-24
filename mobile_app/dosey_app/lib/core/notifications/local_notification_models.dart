class LocalNotificationSound {
  const LocalNotificationSound({
    required this.androidResourceName,
    required this.appleFileName,
  });

  final String androidResourceName;
  final String appleFileName;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LocalNotificationSound &&
            other.androidResourceName == androidResourceName &&
            other.appleFileName == appleFileName;
  }

  @override
  int get hashCode => Object.hash(androidResourceName, appleFileName);
}

class LocalNotificationChannel {
  const LocalNotificationChannel({
    required this.id,
    required this.name,
    required this.description,
    required this.sound,
  });

  final String id;
  final String name;
  final String description;
  final LocalNotificationSound sound;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LocalNotificationChannel &&
            other.id == id &&
            other.name == name &&
            other.description == description &&
            other.sound == sound;
  }

  @override
  int get hashCode => Object.hash(id, name, description, sound);
}

const doseyReminderNotificationSound = LocalNotificationSound(
  androidResourceName: 'dosey_reminder',
  appleFileName: 'dosey_reminder.aiff',
);

const doseyReminderNotificationChannel = LocalNotificationChannel(
  id: 'dosey_reminders',
  name: 'Dose reminders',
  description: 'Dosey reminder alerts for scheduled doses.',
  sound: doseyReminderNotificationSound,
);

const doseyUrgentShortageNotificationChannel = LocalNotificationChannel(
  id: 'dosey_urgent_shortages',
  name: 'Urgent shortages',
  description: 'Urgent local-only shortage alerts that need reload review.',
  sound: doseyReminderNotificationSound,
);
