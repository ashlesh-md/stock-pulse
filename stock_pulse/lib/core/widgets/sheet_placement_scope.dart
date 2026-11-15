import 'package:flutter/widgets.dart';

class SheetPlacementScope extends InheritedWidget {
  const SheetPlacementScope({super.key, required super.child});

  static bool usesSideSheet(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SheetPlacementScope>() != null;

  @override
  bool updateShouldNotify(SheetPlacementScope oldWidget) => false;
}
