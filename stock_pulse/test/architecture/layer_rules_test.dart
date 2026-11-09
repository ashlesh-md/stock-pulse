import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('layer rules', () {
    test('no lib/ import breaks the ADR-0009 table', () {
      final violations = findViolations(readLibImports(Directory('lib')));
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('presentation may not import data/ or a data providers file', () {
      expect(
        violationsOf('features/market/presentation/a.dart', [
          'features/market/data/live_market_repository.dart',
          'features/market/di/market_data_providers.dart',
          'features/market/di/market_providers.dart',
          'features/market/application/watchlist_controller.dart',
        ]),
        hasLength(2),
      );
    });

    test('application may not import data/, material or widgets', () {
      expect(
        violationsOf(
          'features/orders/application/c.dart',
          [
            'features/orders/data/live_order_repository.dart',
            'features/orders/orders_providers.dart',
            'core/network/application/connection_controller.dart',
          ],
          packages: [
            'package:flutter/material.dart',
            'package:flutter/widgets.dart',
            'package:flutter/foundation.dart',
          ],
        ),
        hasLength(3),
      );
    });

    test(
      'domain imports no Flutter but foundation, no riverpod, http or io',
      () {
        expect(
          violationsOf(
            'features/market/domain/quote.dart',
            ['features/market/application/x.dart', 'core/error/result.dart'],
            packages: [
              'package:flutter/foundation.dart',
              'package:flutter_riverpod/flutter_riverpod.dart',
              'package:http/http.dart',
              'dart:io',
              'package:option_math/option_math.dart',
            ],
          ),
          hasLength(4),
        );
      },
    );

    test('data may not import application/, presentation/ or riverpod', () {
      expect(
        violationsOf(
          'features/market/data/r.dart',
          [
            'features/market/domain/quote.dart',
            'core/network/data/api_client.dart',
            'features/market/application/x.dart',
            'features/market/presentation/y.dart',
          ],
          packages: ['package:flutter_riverpod/flutter_riverpod.dart'],
        ),
        hasLength(3),
      );
    });

    test('a providers file may wire application/ but not presentation/', () {
      expect(
        violationsOf('features/market/di/market_providers.dart', [
          'features/market/data/live_market_repository.dart',
          'core/network/di/network_providers.dart',
          'features/market/application/x.dart',
          'features/market/presentation/y.dart',
        ]),
        hasLength(1),
      );
    });

    test('core never imports features/ or app/; app imports anything', () {
      expect(
        violationsOf('core/widgets/w.dart', [
          'features/market/domain/quote.dart',
          'app/app.dart',
          'core/theme/sp_colors.dart',
        ]),
        hasLength(2),
      );
      expect(
        violationsOf('app/app.dart', ['features/market/data/x.dart']),
        isEmpty,
      );
    });
  });
}

List<String> violationsOf(
  String from,
  List<String> libImports, {
  List<String> packages = const [],
}) => findViolations({
  from: [for (final i in libImports) 'package:stock_pulse/$i', ...packages],
});

const _self = 'package:stock_pulse/';

enum Layer { domain, data, providers, application, presentation, app, other }

/// Layer of a path relative to `lib/`, such as
/// `features/market/data/live_market_repository.dart`.
Layer layerOf(String path) {
  if (path.startsWith('app/') || !path.contains('/')) return Layer.app;
  if (path.endsWith('_providers.dart')) return Layer.providers;
  final segments = path.split('/');
  for (final layer in [
    Layer.domain,
    Layer.data,
    Layer.application,
    Layer.presentation,
  ]) {
    if (segments.contains(layer.name)) return layer;
  }
  return Layer.other;
}

/// Imports of each `lib/` file, keyed by its path relative to `lib/`.
Map<String, List<String>> readLibImports(Directory lib) {
  final pattern = RegExp(r'''^import\s+['"]([^'"]+)['"]''', multiLine: true);
  final prefix = '${lib.path}/';
  return {
    for (final file in lib.listSync(recursive: true).whereType<File>())
      if (file.path.endsWith('.dart'))
        file.path.substring(prefix.length): [
          for (final m in pattern.allMatches(file.readAsStringSync()))
            m.group(1)!,
        ],
  };
}

/// One line per forbidden import: `from -> import (reason)`.
List<String> findViolations(Map<String, List<String>> importsByFile) {
  final violations = <String>[];
  for (final MapEntry(key: from, value: imports) in importsByFile.entries) {
    for (final uri in imports) {
      final reason = _forbiddenReason(from, uri);
      if (reason != null) violations.add('$from -> $uri ($reason)');
    }
  }
  return violations..sort();
}

String? _forbiddenReason(String from, String uri) {
  final fromLayer = layerOf(from);
  if (fromLayer == Layer.app) return null;
  final target = uri.startsWith(_self) ? uri.substring(_self.length) : null;
  if (from.startsWith('core/') && target != null) {
    if (target.startsWith('features/') || layerOf(target) == Layer.app) {
      return 'core imports features or app';
    }
  }
  return switch (fromLayer) {
    Layer.domain => _domainRule(uri, target),
    Layer.data => _dataRule(uri, target),
    Layer.providers => _providersRule(target),
    Layer.application => _applicationRule(uri, target),
    Layer.presentation => _presentationRule(target),
    Layer.app || Layer.other => null,
  };
}

bool _isRiverpod(String uri) => uri.startsWith('package:flutter_riverpod/');

bool _isWidgets(String uri) =>
    uri == 'package:flutter/material.dart' ||
    uri == 'package:flutter/widgets.dart' ||
    uri == 'package:flutter/cupertino.dart';

String? _domainRule(String uri, String? target) {
  if (target != null) {
    final layer = layerOf(target);
    final allowed = layer == Layer.domain || target.startsWith('core/error/');
    return allowed ? null : 'domain imports ${layer.name}';
  }
  if (uri.startsWith('package:flutter/') &&
      uri != 'package:flutter/foundation.dart') {
    return 'domain imports Flutter UI';
  }
  if (_isRiverpod(uri) || uri.startsWith('package:http/') || uri == 'dart:io') {
    return 'domain imports I/O or riverpod';
  }
  return null;
}

String? _dataRule(String uri, String? target) {
  if (_isRiverpod(uri)) return 'data imports riverpod';
  return switch (target == null ? null : layerOf(target)) {
    Layer.application => 'data imports application',
    Layer.presentation => 'data imports presentation',
    _ => null,
  };
}

String? _providersRule(String? target) =>
    switch (target == null ? null : layerOf(target)) {
      Layer.presentation => 'providers file imports presentation',
      _ => null,
    };

String? _applicationRule(String uri, String? target) {
  if (_isWidgets(uri)) return 'application imports widgets';
  return switch (target == null ? null : layerOf(target)) {
    Layer.data => 'application imports data',
    Layer.presentation => 'application imports presentation',
    _ => null,
  };
}

String? _presentationRule(String? target) {
  if (target != null && target.endsWith('_data_providers.dart')) {
    return 'presentation imports a data providers file';
  }
  return switch (target == null ? null : layerOf(target)) {
    Layer.data => 'presentation imports data',
    _ => null,
  };
}
