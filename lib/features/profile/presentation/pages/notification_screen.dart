import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/widgets/flixie_back_button.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flixie_app/models/notification.dart';
import '../controllers/notification_inbox_controller.dart';
import '../notification_inbox_actions.dart';
import '../widgets/notification_inbox/notification_inbox_view.dart';
import '../widgets/notification_inbox/notification_options_sheet.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});
  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with WidgetsBindingObserver {
  late final NotificationInboxController _inbox;
  AuthProvider? _auth;
  bool _routeVisible = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _inbox = NotificationInboxController(onCache: (user, items) {
      final auth = _auth;
      if (auth?.dbUser?.id == user) {
        auth!.updateCachedNotifications(items, unreadCount: _inbox.unreadCount);
      }
    })
      ..addListener(_onInboxChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    if (_auth != auth) {
      _auth?.removeListener(_onAuthChanged);
      _auth = auth;
      auth.addListener(_onAuthChanged);
    }
    _routeVisible = ModalRoute.isCurrentOf(context) ?? true;
    _onAuthChanged();
    _inbox.setActive(_routeVisible && _foreground);
  }

  void _onAuthChanged() =>
      _inbox.bind(_auth?.dbUser?.id, _auth?.cachedNotifications,
          totalUnread: _auth?.unreadNotificationCount);
  void _onInboxChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _inbox.setActive(_routeVisible && _foreground);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth?.removeListener(_onAuthChanged);
    _inbox.dispose();
    super.dispose();
  }

  void _errorToast(String message) {
    ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
        type: FlixieToastType.error,
        content: Text(message),
        backgroundColor: context.colors.danger));
  }

  Future<void> _dismiss(FlixieNotification notification) async {
    final token = _inbox.generation;
    final saved = await _inbox.dismiss(notification);
    if (mounted && _inbox.owns(token) && saved == false) {
      _errorToast('Failed to dismiss notification.');
    }
  }

  Future<void> _setRead(FlixieNotification notification, bool read) async {
    final token = _inbox.generation;
    final saved = await _inbox.setRead(notification, read);
    if (mounted && _inbox.owns(token) && saved == false) {
      _errorToast('Could not update notification. Try again.');
    }
  }

  Future<void> _markAllRead() async {
    final token = _inbox.generation;
    final saved = await _inbox.markAllRead();
    if (mounted && _inbox.owns(token) && !saved) {
      _errorToast('Could not update notification. Try again.');
    }
  }

  void _showOptions(FlixieNotification notification) {
    final token = _inbox.generation;
    showNotificationOptions(context, notification,
        onRead: (read) => _setRead(notification, read),
        onDismiss: () => _dismiss(notification),
        isCurrent: () => mounted && _inbox.owns(token));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Notifications'),
            leading: const FlixieBackButton()),
        body: RefreshIndicator(
          onRefresh: _inbox.refresh,
          color: FlixieColors.primary,
          child: NotificationInboxView(
            key: ValueKey(_inbox.userId),
            notifications: _inbox.notifications,
            processingIds: _inbox.processingIds,
            loading: _inbox.loading,
            hasMore: _inbox.hasMore,
            unreadCount: _inbox.unreadCount,
            loadingMore: _inbox.loadingMore,
            pageError: _inbox.pageError,
            onLoadMore: _inbox.loadMore,
            error: _inbox.error,
            onRetry: () => _inbox.refresh(showSpinner: true),
            onMarkAllRead: _markAllRead,
            onDismiss: _dismiss,
            onOptions: _showOptions,
            onRespond: (n, action) =>
                respondToInboxNotification(context, _inbox, n, action),
            onOpen: (n, route) {
              if (!n.isRead) unawaited(_setRead(n, true));
              context.push(route);
            },
          ),
        ),
      );
}
