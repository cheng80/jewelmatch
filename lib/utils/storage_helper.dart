import 'package:shared_preferences/shared_preferences.dart';

/// shared_preferences 래퍼. 앱 전역에서 사용하는 로컬 저장소 관리.
class StorageHelper {
  StorageHelper._();

  static SharedPreferences? _prefs;

  /// 초기화 (앱 시작 시 호출)
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get _store {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('StorageHelper.init() must be called before use.');
    }
    return prefs;
  }

  /// 읽기. 없으면 null.
  static T? read<T>(String key) {
    final value = _store.get(key);
    if (value is T) return value;
    return null;
  }

  /// 쓰기
  static Future<void> write(String key, Object? value) async {
    if (value == null) {
      await remove(key);
      return;
    }
    switch (value) {
      case bool v:
        await _store.setBool(key, v);
      case int v:
        await _store.setInt(key, v);
      case double v:
        await _store.setDouble(key, v);
      case String v:
        await _store.setString(key, v);
      case List<String> v:
        await _store.setStringList(key, v);
      default:
        throw ArgumentError.value(
          value,
          'value',
          'Unsupported shared_preferences value type.',
        );
    }
  }

  /// 삭제
  static Future<void> remove(String key) async {
    await _store.remove(key);
  }

  /// 전체 삭제
  static Future<void> erase() async {
    await _store.clear();
  }

  /// 키 존재 여부
  static bool hasData(String key) => _store.containsKey(key);

  /// bool 읽기 (기본값 포함)
  static bool readBool(String key, {bool defaultValue = false}) =>
      _store.getBool(key) ?? defaultValue;

  /// double 읽기 (기본값 포함)
  static double readDouble(String key, {double defaultValue = 0.0}) {
    final value = _store.get(key);
    return value is num ? value.toDouble() : defaultValue;
  }

  /// int 읽기 (기본값 포함)
  static int readInt(String key, {int defaultValue = 0}) {
    final value = _store.get(key);
    return value is num ? value.toInt() : defaultValue;
  }

  /// String 읽기 (기본값 포함)
  static String readString(String key, {String defaultValue = ''}) =>
      _store.getString(key) ?? defaultValue;
}
