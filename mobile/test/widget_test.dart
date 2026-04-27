import 'package:flutter_test/flutter_test.dart';
import 'package:pawplan_mobile/api/api_client.dart';
import 'package:pawplan_mobile/main.dart';
import 'package:pawplan_mobile/services/local_notification_service.dart';
import 'package:pawplan_mobile/services/session_store.dart';

void main() {
  testWidgets('shows auth screen first', (tester) async {
    await tester.pumpWidget(
      PawPlanApp(
        apiClient: ApiClient(baseUrl: 'http://localhost:4000/api/v1'),
        notifications: LocalNotificationService(enabled: false),
        sessionStore: SessionStore(enabled: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PawPlan'), findsOneWidget);
    expect(find.text('로그인'), findsWidgets);
  });
}
