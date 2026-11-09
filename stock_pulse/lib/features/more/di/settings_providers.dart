import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/storage/domain/local_prefs.dart';
import 'package:stock_pulse/features/more/application/settings_controller.dart';

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, LocalPrefsData>(
      SettingsController.new,
    );
