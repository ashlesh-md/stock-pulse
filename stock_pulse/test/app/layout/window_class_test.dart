import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/app/layout/max_width_box.dart';
import 'package:stock_pulse/app/layout/window_class.dart';

void main() {
  test('breakpoints: compact < 600 <= medium < 1024 <= expanded', () {
    expect(WindowClass.fromWidth(0), WindowClass.compact);
    expect(WindowClass.fromWidth(599.9), WindowClass.compact);
    expect(WindowClass.fromWidth(600), WindowClass.medium);
    expect(WindowClass.fromWidth(1023.9), WindowClass.medium);
    expect(WindowClass.fromWidth(1024), WindowClass.expanded);
    expect(WindowClass.fromWidth(2560), WindowClass.expanded);
  });

  test('rail on medium and up, two panes on expanded only', () {
    expect(WindowClass.compact.usesRail, isFalse);
    expect(WindowClass.medium.usesRail, isTrue);
    expect(WindowClass.expanded.usesRail, isTrue);
    expect(WindowClass.medium.showsTwoPanes, isFalse);
    expect(WindowClass.expanded.showsTwoPanes, isTrue);
  });

  testWidgets('context.windowClass reads the window width', (tester) async {
    tester.view.physicalSize = const Size(700, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late WindowClass seen;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          seen = context.windowClass;
          return const SizedBox();
        },
      ),
    );
    expect(seen, WindowClass.medium);
  });

  testWidgets('MaxWidthBox caps a wide window and fills a narrow one', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const content = Key('content');
    await tester.pumpWidget(
      const MaterialApp(
        home: MaxWidthBox(
          maxWidth: ContentWidth.list,
          child: SizedBox.expand(key: content),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(content)).width, ContentWidth.list);
    expect(tester.getCenter(find.byKey(content)).dx, 800);

    tester.view.physicalSize = const Size(400, 900);
    await tester.pump();
    expect(tester.getSize(find.byKey(content)).width, 400);
  });
}
