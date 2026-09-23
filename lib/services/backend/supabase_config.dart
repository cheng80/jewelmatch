/// Supabase 연결 값. 빌드할 때 dart-define으로 넣고 코드와 문서에는 값을 쓰지 않는다.
///
///     --dart-define-from-file=config/supabase.json
///
/// 값이 없거나 https 주소가 아니면 모든 Supabase 기능은 비활성(notConfigured)이다.
class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.publishableKey});

  static const SupabaseConfig fromEnvironment = SupabaseConfig(
    url: String.fromEnvironment('SUPABASE_URL'),
    publishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  final String url;

  /// 공개용 키(sb_publishable_...). secret/service_role 키는 절대 넣지 않는다.
  final String publishableKey;

  bool get isConfigured {
    if (publishableKey.isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  String get baseUrl =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
