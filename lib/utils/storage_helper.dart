import 'package:get_storage/get_storage.dart';

/// GetStorage 래퍼. 앱 전역에서 사용하는 로컬 저장소 관리.
class StorageHelper {
  StorageHelper._();

  static final GetStorage _box = GetStorage();

  /// 초기화 (앱 시작 시 호출)
  static Future<void> init() async => GetStorage.init();

  /// 읽기. 없으면 null.
  static T? read<T>(String key) => _box.read<T>(key);

  /// 쓰기
  static Future<void> write(String key, dynamic value) =>
      _box.write(key, value);

  /// 삭제
  static Future<void> remove(String key) => _box.remove(key);

  /// 전체 삭제
  static Future<void> erase() => _box.erase();

  /// 키 존재 여부
  static bool hasData(String key) => _box.hasData(key);

  /// bool 읽기 (기본값 포함)
  static bool readBool(String key, {bool defaultValue = false}) =>
      _box.read<bool>(key) ?? defaultValue;

  /// double 읽기 (기본값 포함)
  static double readDouble(String key, {double defaultValue = 0.0}) =>
      (_box.read<num>(key) ?? defaultValue).toDouble();

  /// int 읽기 (기본값 포함)
  static int readInt(String key, {int defaultValue = 0}) =>
      (_box.read<num>(key) ?? defaultValue).toInt();

  /// String 읽기 (기본값 포함)
  static String readString(String key, {String defaultValue = ''}) =>
      _box.read<String>(key) ?? defaultValue;
}
