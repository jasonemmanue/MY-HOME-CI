import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/app_notification.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../chat/chat_detail_screen.dart';
import '../property_detail/property_detail_screen.dart';

/// Historique des notifications.
///
/// Nécessaire en complément du push : une notification balayée depuis l'écran
/// de verrouillage est définitivement perdue, alors que l'information (annonce
/// validée, alerte déclenchée) reste utile plusieurs jours.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (uid != null)
            TextButton(
              onPressed: () => NotificationService.instance.markAllRead(uid),
              child: Text(
                'Tout lire',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppTheme.primaryGreen),
              ),
            ),
        ],
      ),
      body: uid == null
          ? _empty(context, 'Connectez-vous pour voir vos notifications.')
          : StreamBuilder<List<AppNotification>>(
              stream: NotificationService.instance.watchNotifications(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? const <AppNotification>[];
                if (items.isEmpty) {
                  return _empty(context, 'Aucune notification pour le moment.');
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) =>
                      _tile(context, uid, items[i]),
                );
              },
            ),
    );
  }

  Widget _tile(BuildContext context, String uid, AppNotification n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      onTap: () {
        if (!n.isRead) NotificationService.instance.markRead(uid, n.id);
        _openTarget(context, n);
      },
      leading: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _color(n.type).withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(_icon(n.type), size: 20, color: _color(n.type)),
      ),
      title: Text(
        n.title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            n.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 4),
          Text(
            timeago.format(n.createdAt, locale: 'fr'),
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
      trailing: n.isRead
          ? null
          : Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: AppTheme.secondaryOrange,
                shape: BoxShape.circle,
              ),
            ),
    );
  }

  void _openTarget(BuildContext context, AppNotification n) {
    if (n.targetId == null) return;
    switch (n.type) {
      case NotificationType.message:
        Navigator.pushNamed(context, AppRoutes.chatDetail,
            arguments: ChatDetailArgs(conversationId: n.targetId!));
        break;
      case NotificationType.alertMatch:
      case NotificationType.propertyApproved:
      case NotificationType.propertyRejected:
      case NotificationType.boostActivated:
        Navigator.pushNamed(context, AppRoutes.propertyDetail,
            arguments: PropertyDetailArgs(propertyId: n.targetId!));
        break;
      default:
        break;
    }
  }

  IconData _icon(NotificationType type) {
    switch (type) {
      case NotificationType.message:
        return Icons.chat_bubble_outline;
      case NotificationType.alertMatch:
        return Icons.notifications_active_outlined;
      case NotificationType.propertyApproved:
        return Icons.check_circle_outline;
      case NotificationType.propertyRejected:
        return Icons.cancel_outlined;
      case NotificationType.verificationApproved:
        return Icons.verified_outlined;
      case NotificationType.verificationRejected:
        return Icons.gpp_bad_outlined;
      case NotificationType.proActivated:
        return Icons.workspace_premium_outlined;
      case NotificationType.boostActivated:
        return Icons.trending_up;
      case NotificationType.admin:
        return Icons.campaign_outlined;
    }
  }

  Color _color(NotificationType type) {
    switch (type) {
      case NotificationType.propertyRejected:
      case NotificationType.verificationRejected:
        return const Color(0xFFD64545);
      case NotificationType.proActivated:
      case NotificationType.boostActivated:
      case NotificationType.alertMatch:
        return AppTheme.secondaryOrange;
      default:
        return AppTheme.primaryGreen;
    }
  }

  Widget _empty(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none,
                size: 56,
                color: Theme.of(context).disabledColor.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
