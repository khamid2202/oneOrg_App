import 'package:flutter_test/flutter_test.dart';
import 'package:one_org_staff/config/api_config.dart';

void main() {
  test('store builds use production, everything else dev', () {
    expect(
      ApiConfig.resolveBaseUrl('', release: true),
      'https://api.oneorg.uz',
    );
    expect(
      ApiConfig.resolveBaseUrl('', release: false),
      'https://dev-api.oneorg.uz',
    );
  });

  test('an explicit address wins and loses its trailing slash', () {
    expect(
      ApiConfig.resolveBaseUrl(' https://staging.test/ ', release: true),
      'https://staging.test',
    );
  });

  test('tests run against dev', () {
    expect(ApiConfig.baseUrl, ApiConfig.developmentUrl);
  });
}
