import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

const List<double> _milestoneThresholds = [
  1000, 5000, 10000, 25000, 50000, 100000,
  250000, 500000, 1000000, 2500000, 5000000, 10000000,
];

class NotificationService {
  static const _channelId = 'moneii_milestones';
  static const _channelName = 'Net Worth Milestones';
  static const _prefKey = 'highest_notified_milestone';

  static final _plugin = FlutterLocalNotificationsPlugin();

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> init() async {
    if (!_supported) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
  }

  static Future<void> requestPermission() async {
    if (!_supported) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> checkAndNotifyMilestone(
    double currentNetWorth,
    String currencySymbol,
    SharedPreferences prefs,
  ) async {
    if (!_supported) return;
    final highestNotified = prefs.getDouble(_prefKey) ?? 0.0;

    double? newMilestone;
    for (final threshold in _milestoneThresholds) {
      if (currentNetWorth >= threshold && threshold > highestNotified) {
        newMilestone = threshold;
      }
    }
    if (newMilestone == null) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Celebrate your net worth milestones',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    final label = _formatMilestone(newMilestone, currencySymbol);
    await _plugin.show(
      newMilestone.hashCode & 0x7FFFFFFF,
      '🎯 Milestone reached!',
      "You just hit $label net worth. Keep it up!",
      details,
    );

    await prefs.setDouble(_prefKey, newMilestone);
  }

  static String _formatMilestone(double value, String symbol) {
    if (value >= 1000000) {
      return '$symbol${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      return '$symbol${(value / 1000).toStringAsFixed(0)}K';
    }
    return '$symbol${value.toStringAsFixed(0)}';
  }
}
