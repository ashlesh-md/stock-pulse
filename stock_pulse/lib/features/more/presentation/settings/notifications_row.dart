import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/push/di/push_providers.dart';
import 'package:stock_pulse/core/push/domain/push_permission_service.dart';

/// Price-alert notification permission: asks once, then links to the
/// system settings while it is off.
class NotificationsRow extends ConsumerStatefulWidget {
  const NotificationsRow({super.key});

  @override
  ConsumerState<NotificationsRow> createState() => _NotificationsRowState();
}

class _NotificationsRowState extends ConsumerState<NotificationsRow> {
  late Future<PushPermissionStatus> _status;

  @override
  void initState() {
    super.initState();
    _status = ref.read(pushPermissionServiceProvider).status();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.more;
    return FutureBuilder(
      future: _status,
      builder: (context, snapshot) {
        final enabled = snapshot.data == PushPermissionStatus.granted;
        return ListTile(
          title: Text(strings.notifications),
          subtitle: Text(enabled ? '' : strings.notificationsOff),
          trailing: Icon(
            enabled ? AppIcons.notifications : AppIcons.notificationsOff,
          ),
          onTap: () async {
            final service = ref.read(pushPermissionServiceProvider);
            final status = await service.status();
            if (status == PushPermissionStatus.notDetermined) {
              await service.request();
            } else if (status != PushPermissionStatus.granted) {
              await service.openSettings();
            }
            if (!mounted) return;
            // A block body: an arrow would return the Future, which
            // setState rejects.
            setState(() {
              _status = service.status();
            });
          },
        );
      },
    );
  }
}
