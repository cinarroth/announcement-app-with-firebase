import 'package:admin_app/screens/setup_required_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('yapılandırma eksikse kullanıcı doğru yönlendirilir', (tester) async {
    await tester.pumpWidget(const SetupRequiredApp(appName: 'admin_app'));

    expect(find.text('Firebase yapılandırması eksik'), findsOneWidget);
    expect(find.textContaining('flutterfire configure'), findsOneWidget);
    expect(find.textContaining('admin_app'), findsOneWidget);
  });
}
