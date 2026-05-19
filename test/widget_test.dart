import 'package:flutter_test/flutter_test.dart';
import 'package:informal_service_agent/main.dart';

void main() {
  test('KaarigarApp smoke test', () {
    const app = KaarigarApp();
    expect(app, isNotNull);
  });
}
