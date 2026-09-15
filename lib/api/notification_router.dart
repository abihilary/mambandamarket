import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Screens/NotificationsScreen.dart';
import '../Screens/NotificationDetailScreen.dart';
import 'models.dart';
import '../Screens/OrderDetailScreen.dart';
import '../Screens/ShipmentsScreen.dart';
import '../Service/ChatRoomScreen.dart';
import '../navigation.dart';
import 'notification_repository.dart';
import 'repositories.dart';

/// Routes the app may be sent to by name from a notification. A closed list:
/// a push is server data, and "open any route" would let a typo land someone
/// on the reset-password screen.
const _openableRoutes = <String>{'/home', '/my-orders', '/subscription', '/invite', '/referral', '/notifications'};

/// Where a notification's tap goes.
///
/// One function for every entry: a tap in the shade, a tap on the launch
/// notification, a tap in the inbox list. `data.type` decides; the ids inside
/// are fetched over the API rather than trusted, the same way a shared link
/// is. Never throws — landing in the app beats an error screen.
/// Whether `data` points somewhere specific — a thread, a parcel, an order, a
/// listing, a page — or is only news, which is read in full on its own screen.
bool notificationHasTarget(Map<String, dynamic> data) {
  switch (data['type']?.toString() ?? '') {
    case 'message':
      return (data['conversation_id']?.toString() ?? '').isNotEmpty;
    case 'shipping':
    case 'order':
    case 'listing':
      return (data['id']?.toString() ?? '').isNotEmpty;
    case 'url':
      final url = Uri.tryParse(data['url']?.toString() ?? '');
      return url != null && (url.scheme == 'https' || url.scheme == 'http');
    case 'screen':
      final route = data['route']?.toString() ?? '';
      return _openableRoutes.contains(route) && route != '/notifications';
    default:
      return false;
  }
}

/// Show one notification in full. Used by the inbox list, and by a tap on
/// the shade for anything that has no target of its own.
Future<void> openNotificationDetail(AppNotification n) async {
  final navigator = rootNavigatorKey.currentState;
  if (navigator == null) return;
  await navigator.push(MaterialPageRoute(builder: (_) => NotificationDetailScreen(notification: n)));
}

Future<void> openNotificationTarget(Map<String, dynamic> data) async {
  final navigator = rootNavigatorKey.currentState;
  if (navigator == null) return;

  // Awaited, not fire-and-forget: the inbox screen a tap may land on reloads
  // the list, and a read that is still in flight would come back unread.
  final notificationId = data['notification_id']?.toString();
  if (notificationId != null && notificationId.isNotEmpty) {
    try {
      await NotificationRepository.instance.markRead([notificationId]).timeout(const Duration(seconds: 3));
    } catch (_) {
      // Marked locally already; the server catches up on the next read.
    }
  }

  final type = data['type']?.toString() ?? '';
  final id = data['id']?.toString() ?? '';
  try {
    switch (type) {
      case 'message':
        final conversationId = data['conversation_id']?.toString();
        if (conversationId == null || conversationId.isEmpty) return;
        final thread = await ChatRepository.instance.thread(conversationId);
        await navigator.push(MaterialPageRoute(builder: (_) => ChatRoomScreen(conversation: thread)));
        return;
      case 'shipping':
        if (id.isEmpty) break;
        await navigator.push(MaterialPageRoute(builder: (_) => ShipmentDetailScreen(id: id)));
        return;
      case 'order':
        if (id.isEmpty) break;
        await navigator.push(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: id)));
        return;
      case 'listing':
        if (id.isEmpty) break;
        await openSharedListing(id);
        return;
      case 'url':
        final url = Uri.tryParse(data['url']?.toString() ?? '');
        if (url != null && (url.scheme == 'https' || url.scheme == 'http')) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          return;
        }
        break;
      case 'screen':
        final route = data['route']?.toString() ?? '';
        if (_openableRoutes.contains(route) && route != '/notifications') {
          await navigator.pushNamed(route);
          return;
        }
        break;
    }
    // announcement, desk, direct, system, and anything unknown: the row in
    // full when we know which one it is, else the inbox.
    if (notificationId != null && notificationId.isNotEmpty) {
      try {
        final n = await NotificationRepository.instance.fetch(notificationId);
        await openNotificationDetail(n);
        return;
      } catch (e) {
        debugPrint('[notifications] could not fetch $notificationId ($e)');
      }
    }
    await navigator.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  } catch (e) {
    debugPrint('[notifications] could not open $type $id ($e)');
  }
}
