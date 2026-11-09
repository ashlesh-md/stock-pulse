import 'package:flutter/material.dart';

import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/network/domain/socket_status.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';

/// One raw socket frame: direction, time and up to three lines of JSON.
class FrameTile extends StatelessWidget {
  const FrameTile({super.key, required this.frame});

  final SocketFrame frame;

  @override
  Widget build(BuildContext context) {
    final color = frame.outgoing ? context.sp.info : context.sp.up;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            frame.outgoing ? '↑' : '↓',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 6),
          Text(
            Fmt.time(frame.at),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              frame.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
