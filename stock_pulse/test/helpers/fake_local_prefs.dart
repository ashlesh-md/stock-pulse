import 'package:stock_pulse/core/storage/domain/local_prefs.dart';

/// In-memory [LocalPrefs]. Override with
/// `localPrefsProvider.overrideWith((ref) async => FakeLocalPrefs())`.
class FakeLocalPrefs implements LocalPrefs {
  FakeLocalPrefs([LocalPrefsData initial = LocalPrefsData.defaults])
    : _data = initial;

  LocalPrefsData _data;
  int updates = 0;
  int clears = 0;

  @override
  LocalPrefsData get data => _data;

  @override
  Future<void> update(
    LocalPrefsData Function(LocalPrefsData current) change,
  ) async {
    _data = change(_data);
    updates++;
  }

  @override
  Future<void> clear() async {
    _data = LocalPrefsData.defaults;
    clears++;
  }
}
