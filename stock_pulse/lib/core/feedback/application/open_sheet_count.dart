import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Number of modal sheets open right now. Alert banners wait while it is
/// above 0; `showSpSheet` counts itself in and out.
class OpenSheetCount extends Notifier<int> {
  @override
  int build() => 0;

  void inc() => state++;

  void dec() {
    if (state > 0) state--;
  }
}
