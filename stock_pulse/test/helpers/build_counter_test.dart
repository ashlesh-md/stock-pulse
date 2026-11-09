import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'build_counter.dart';

class _Row extends StatelessWidget {
  const _Row({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, textDirection: TextDirection.ltr);
}

void main() {
  testWidgets('counts builds per key and per type', (tester) async {
    final counter = BuildCounter.attach();
    addTearDown(counter.detach);

    Widget tree(String b) => Column(
      children: [
        const _Row(key: ValueKey('A'), text: 'a'),
        _Row(key: const ValueKey('B'), text: b),
      ],
    );

    await tester.pumpWidget(
      Directionality(textDirection: TextDirection.ltr, child: tree('b')),
    );
    expect(counter.ofKey(const ValueKey('A')), 1);
    counter.reset();

    await tester.pumpWidget(
      Directionality(textDirection: TextDirection.ltr, child: tree('b2')),
    );
    expect(
      counter.ofKey(const ValueKey('A')),
      0,
      reason: 'const row is not rebuilt',
    );
    expect(counter.ofKey(const ValueKey('B')), 1);
    expect(counter.ofType<_Row>(), 1);
  });
}
