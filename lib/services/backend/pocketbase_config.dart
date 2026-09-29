/// 공개 앱 URL만 빌드에 포함한다. 관리자 자격정보는 사용하지 않는다.
class PocketBaseConfig {
  const PocketBaseConfig({required this.url});
  static const fromEnvironment = PocketBaseConfig(
    url: String.fromEnvironment('POCKETBASE_URL'),
  );
  final String url;
  bool get isConfigured {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }

  String get baseUrl =>
      Uri.parse(url).toString().replaceFirst(RegExp(r'/+$'), '');
}
