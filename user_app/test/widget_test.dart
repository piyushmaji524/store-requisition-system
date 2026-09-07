import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const StoreRequisitionApp());
    expect(find.text('Store Requisition'), findsOneWidget);
  });
}
