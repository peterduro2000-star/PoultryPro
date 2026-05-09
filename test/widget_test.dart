import 'package:flutter_test/flutter_test.dart';

import 'package:poultry_pro_new/main.dart';

void main() {
  testWidgets('Poultry Pro launches the main shell', (tester) async {
    await tester.pumpWidget(const PoultryProApp());
    await tester.pumpAndSettle();

    expect(find.text('Poultry Pro'), findsOneWidget);
  });
}
