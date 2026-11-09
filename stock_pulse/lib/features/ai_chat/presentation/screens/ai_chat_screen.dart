import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/app/di/layout_providers.dart';
import 'package:stock_pulse/app/layout/window_class.dart';
import 'package:stock_pulse/app/router/movable_tab_shortcut.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';
import 'package:stock_pulse/features/ai_chat/application/chat_state.dart';
import 'package:stock_pulse/features/ai_chat/di/ai_chat_providers.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_limits.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/chat_answer_item.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/chat_composer.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/chat_dock.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/chat_empty_state.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/chat_follow_ups.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/new_answer_pill.dart';

/// The list is reversed: offset 0 is the newest answer at the bottom. An
/// answer that grows while the user is at the bottom stays pinned there with
/// no scroll jumps, and older pages join at the far end without moving what
/// is on screen.
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  final _pill = ValueNotifier(false);
  bool _movingToBottom = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state
        case AppLifecycleState.paused ||
            AppLifecycleState.hidden ||
            AppLifecycleState.detached) {
      unawaited(ref.read(chatControllerProvider.notifier).stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    _pill.dispose();
    super.dispose();
  }

  bool get _atBottom =>
      !_scroll.hasClients || _scroll.position.pixels <= ChatLimits.bottomSlack;

  void _onScroll() {
    if (_atBottom) _pill.value = false;
    _loadOlderIfNear();
  }

  void _loadOlderIfNear() {
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < ChatLimits.loadAhead) {
      unawaited(ref.read(chatControllerProvider.notifier).loadOlder());
    }
  }

  void _toBottom() {
    _pill.value = false;
    if (_scroll.hasClients && _scroll.position.pixels > 0) {
      unawaited(_animateToBottom());
    }
  }

  Future<void> _animateToBottom() async {
    if (!_scroll.hasClients) return;
    _movingToBottom = true;
    try {
      await _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _movingToBottom = false;
      if (mounted && _atBottom) _pill.value = false;
    }
  }

  void _onOutline(ChatOutline? before, ChatOutline? after) {
    if (after == null) return;
    final asked =
        after.ids.isNotEmpty && after.ids.last != before?.ids.lastOrNull;
    if (after.ids.isEmpty) {
      _pill.value = false;
    } else if (asked) {
      _toBottom();
    } else if (after.lastCards > (before?.lastCards ?? 0) &&
        !_atBottom &&
        !_movingToBottom) {
      _pill.value = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadOlderIfNear();
    });
  }

  Future<void> _confirmNewChat() async {
    final s = context.strings.chat;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.newChatTitle),
        content: Text(s.newChatBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if ((ok ?? false) && mounted) {
      ref.read(chatControllerProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings.chat;
    final outline = ref.watch(
      chatControllerProvider.select((v) => v.whenData((s) => s.outline)),
    );
    ref.listen<ChatOutline?>(
      chatControllerProvider.select((v) => v.value?.outline),
      _onOutline,
    );
    final controller = ref.read(chatControllerProvider.notifier);
    final hasAnswers = outline.value?.ids.isNotEmpty ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.title),
            Text(
              s.subtitle,
              style: context.spText.caption.copyWith(
                color: context.sp.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: s.newChat,
            onPressed: hasAnswers ? () => unawaited(_confirmNewChat()) : null,
            icon: const Icon(AppIcons.newChat),
          ),
        ],
      ),
      body: switch (outline) {
        AsyncData(:final value) => Column(
          children: [
            if (value.historyFailed)
              Container(
                width: double.infinity,
                color: context.sp.surface2,
                padding: const EdgeInsets.symmetric(
                  horizontal: SpSpace.gutter,
                  vertical: SpSpace.s2,
                ),
                child: Text(
                  s.historyFailed,
                  style: context.spText.caption.copyWith(
                    color: context.sp.warn,
                  ),
                ),
              ),
            Expanded(
              child: value.ids.isEmpty
                  ? ChatEmptyState(onPrompt: controller.ask)
                  : Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        _list(value),
                        Padding(
                          padding: const EdgeInsets.only(bottom: SpSpace.s3),
                          child: NewAnswerPill(
                            visible: _pill,
                            onTap: _toBottom,
                          ),
                        ),
                      ],
                    ),
            ),
            ChatDock(
              onHeight: ref.read(chatDockHeightProvider.notifier).set,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!value.busy &&
                      value.ids.isNotEmpty &&
                      value.chips.isNotEmpty)
                    ChatFollowUps(prompts: value.chips, onTap: controller.ask),
                  ChatComposer(
                    busy: value.busy,
                    onSend: (text, attachments) =>
                        controller.ask(text, attachments: attachments),
                    onStop: () => unawaited(controller.stop()),
                    onPickAttachment: controller.pickAttachment,
                  ),
                ],
              ),
            ),
          ],
        ),
        AsyncError() => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(chatControllerProvider),
            child: Text(s.loadingFailed),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _list(ChatOutline value) {
    final ids = value.ids;
    final footer = value.hasOlder || value.loadingOlder;
    // Item heights are estimated until built, so the far end can move closer
    // without a scroll; recheck then, or the next page would never load.
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _loadOlderIfNear();
        return false;
      },
      child: ListView.builder(
        controller: _scroll,
        reverse: true,
        padding: EdgeInsets.fromLTRB(
          SpSpace.gutter,
          SpSpace.s4,
          SpSpace.gutter,
          context.windowClass.usesRail
              ? SpSpace.s2
              : SpSpace.s2 + MovableTabShortcut.dockClearance,
        ),
        itemCount: ids.length + (footer ? 1 : 0),
        findChildIndexCallback: (key) {
          final index = ids.indexOf((key as ValueKey<String>).value);
          return index < 0 ? null : ids.length - 1 - index;
        },
        itemBuilder: (context, i) {
          if (i == ids.length) {
            return Padding(
              padding: const EdgeInsets.all(SpSpace.s3),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: context.strings.chat.loadingOlder,
                  ),
                ),
              ),
            );
          }
          final id = ids[ids.length - 1 - i];
          return ChatAnswerItem(key: ValueKey(id), id: id);
        },
      ),
    );
  }
}
