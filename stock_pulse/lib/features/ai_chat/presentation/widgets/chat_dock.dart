import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The chat's bottom dock (chips and composer). Reports its height after
/// each layout that changes it, so the floating tab shortcut can rest on it.
class ChatDock extends SingleChildRenderObjectWidget {
  const ChatDock({super.key, required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderChatDock(onHeight);

  @override
  void updateRenderObject(BuildContext context, RenderChatDock renderObject) =>
      renderObject.onHeight = onHeight;
}

class RenderChatDock extends RenderProxyBox {
  RenderChatDock(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _reported) return;
    _reported = height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onHeight(height);
    });
  }
}
