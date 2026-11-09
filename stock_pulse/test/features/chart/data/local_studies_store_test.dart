import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:stock_pulse/features/chart/data/local_studies_store.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_kind.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_spec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'store reads empty, round-trips specs and caps saved studies at four',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final store = LocalStudiesStore(SharedPreferencesAsync());
      expect(await store.read('TCS'), isEmpty);

      final specs = StudyKind.values
          .map((kind) => StudySpec(kind: kind, period: 10))
          .toList();
      await store.write('TCS', specs);
      final loaded = await store.read('TCS');
      expect(loaded, specs.take(4));
      expect(await store.read('INFY'), isEmpty);
    },
  );
}
