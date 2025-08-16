import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/goal.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _goalChannel =
  AndroidNotificationChannel(
    'goal_reminders_channel',
    'Goal Reminders',
    description: 'Channel for goal achievement reminders.',
    importance: Importance.max,
  );

  static const AndroidNotificationChannel _timerChannel =
  AndroidNotificationChannel(
    'timer_notif_channel',
    'Active Timer',
    description: 'Notification showing the active timer.',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  );

  static const AndroidNotificationChannel _serviceChannel =
  AndroidNotificationChannel(
    'background_service_notif_channel',
    'Background Service',
    description: 'Channel for the persistent background service notification.',
    importance: Importance.min,
    playSound: false,
    enableVibration: false,
  );

  Future<void> init() async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_goalChannel);
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_timerChannel);
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_serviceChannel);

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@drawable/ic_notification_icon');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> scheduleGoalReminder(Goal goal) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('goalReminderEnabled') ?? true)) return;

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final tz.TZDateTime scheduleTime =
    tz.TZDateTime(tz.local, now.year, now.month, now.day + 1, 20, 0);

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _goalChannel.id,
        _goalChannel.name,
        channelDescription: _goalChannel.description,
        priority: Priority.high,
        importance: Importance.max,
        largeIcon: const DrawableResourceAndroidBitmap('@drawable/ic_notification_icon'),
      ),
    );

    await _notificationsPlugin.zonedSchedule(
      goal.id.hashCode,
      'Stay Locked In: ${goal.activityName}',
      'Your goal for today is ${goal.goalDuration.inMinutes} minutes. Good luck!',
      scheduleTime,
      notificationDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> showTimerNotification(String formattedDuration) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('timerNotificationEnabled') ?? true)) {
      await cancelTimerNotification();
      return;
    }

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _timerChannel.id,
        _timerChannel.name,
        channelDescription: _timerChannel.description,
        ongoing: true,
        autoCancel: false,
        priority: Priority.low,
        importance: Importance.low,
        icon: '@drawable/ic_notification_icon',
      ),
    );

    await _notificationsPlugin.show(
      0,
      'Locked In for $formattedDuration',
      'Keep up the good work!',
      notificationDetails,
    );
  }

  Future<void> showOrUpdateServiceNotification({
    required String title,
    required String content,
  }) async {
    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _serviceChannel.id,
        _serviceChannel.name,
        channelDescription: _serviceChannel.description,
        importance: Importance.min,
        priority: Priority.min,
        ongoing: true,
        autoCancel: false,
        playSound: false,
        enableVibration: false,
        silent: true,
        largeIcon: const DrawableResourceAndroidBitmap('@drawable/ic_bg_notification_icon'),
      ),
    );

    await _notificationsPlugin.show(
      888,
      title,
      content,
      notificationDetails,
    );
  }

  Future<void> cancelTimerNotification() async {
    await _notificationsPlugin.cancel(0);
  }
}