import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab9_clima/main.dart';

void main() {
  testWidgets('Clima app shows title and search field', (tester) async {
    await tester.pumpWidget(const ClimaApp());

    expect(find.text('Clima'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Nhập tên thành phố'), findsOneWidget);
  });
}
