import 'package:flutter/widgets.dart';

/// Counts widget builds in a test through `debugOnRebuildDirtyWidget`, so no
/// production widget needs a test hook.
///
/// ```dart
/// final counter = BuildCounter.attach();
/// addTearDown(counter.detach);
/// ...
/// expect(counter.ofKey(const ValueKey('RELIANCE')), 1);
/// ```
class BuildCounter {
  BuildCounter._();

  factory BuildCounter.attach() {
    assert(
      debugOnRebuildDirtyWidget == null,
      'another BuildCounter is attached',
    );
    final counter = BuildCounter._();
    debugOnRebuildDirtyWidget = counter._onBuild;
    return counter;
  }

  final _byKey = <Key, int>{};
  final _byType = <Type, int>{};

  void _onBuild(Element e, bool builtOnce) {
    final widget = e.widget;
    final key = widget.key;
    if (key != null) _byKey[key] = (_byKey[key] ?? 0) + 1;
    _byType[widget.runtimeType] = (_byType[widget.runtimeType] ?? 0) + 1;
  }

  /// Builds of widgets with [key] since attach or the last [reset].
  int ofKey(Key key) => _byKey[key] ?? 0;

  /// Builds of widgets of type [T] since attach or the last [reset].
  int ofType<T extends Widget>() => _byType[T] ?? 0;

  void reset() {
    _byKey.clear();
    _byType.clear();
  }

  void detach() {
    if (debugOnRebuildDirtyWidget == _onBuild) debugOnRebuildDirtyWidget = null;
  }
}
