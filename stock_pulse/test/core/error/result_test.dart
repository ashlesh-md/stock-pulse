import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';

void main() {
  test('map transforms a value and passes an error through', () {
    expect(const Success(2).map((v) => v * 3).valueOrNull, 6);
    const error = NetworkError();
    final failed = const Failure<int>(error).map((v) => v * 3);
    expect(failed, isA<Failure<int>>().having((f) => f.error, 'e', error));
  });

  test('valueOrNull is null for a failure', () {
    expect(const Failure<int>(ParseError()).valueOrNull, isNull);
  });

  test('getOrThrow returns the value or throws the error', () {
    expect(const Success(1).getOrThrow(), 1);
    expect(
      () => const Failure<int>(NetworkError()).getOrThrow(),
      throwsA(isA<NetworkError>()),
    );
  });

  group('parseJson', () {
    test('a bad cast is a ParseError', () {
      expect(parseJson<int>(() => ('x' as Object) as int), isA<Failure<int>>());
    });

    test('a bad date is a ParseError', () {
      expect(parseJson(() => DateTime.parse('nope')), isA<Failure<DateTime>>());
    });

    test('an unknown enum name is a ParseError', () {
      expect(
        parseJson(() => HttpStatusLike.values.byName('nope')),
        isA<Failure<HttpStatusLike>>(),
      );
    });

    test('a good parse is a Success', () {
      expect(parseJson(() => 4).valueOrNull, 4);
    });
  });

  test('an error prints its log message', () {
    expect('${const ServerError(500, 'c', 'boom')}', 'boom');
  });
}

enum HttpStatusLike { ok }
