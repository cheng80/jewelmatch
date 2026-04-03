import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

import '../app_config.dart';
import '../utils/storage_helper.dart';

/// 인앱 리뷰 서비스.
/// - requestReview: 첫 클리어 후 또는 일정 기간 경과 후 자동 호출 (버튼 사용 금지)
/// - openStoreListing: 설정의 "평점 남기기" 버튼에서 호출
class InAppReviewService {
  InAppReviewService._();

  static final InAppReview _instance = InAppReview.instance;

  /// 웹에서는 인앱 리뷰 미지원. defaultTargetPlatform으로 플랫폼 판별 (dart:io 불필요).
  static bool get _isSupported {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      default:
        return false;
    }
  }

  /// 첫 실행일 저장. main.dart에서 최초 1회 호출.
  static Future<void> saveFirstLaunchDateIfNeeded() async {
    if (StorageHelper.hasData(StorageKeys.firstLaunchDate)) return;
    final now = DateTime.now().toIso8601String();
    await StorageHelper.write(StorageKeys.firstLaunchDate, now);
  }

  /// 첫 클리어 화면 본 후 인앱 리뷰 팝업 요청.
  /// Clear 오버레이가 처음 표시될 때 1회만 호출.
  static Future<void> maybeRequestReviewAfterFirstClear() async {
    if (!_isSupported) return;
    if (StorageHelper.readBool(StorageKeys.reviewRequestedAfterFirstClear)) return;

    StorageHelper.write(StorageKeys.reviewRequestedAfterFirstClear, true);

    if (await _instance.isAvailable()) {
      _instance.requestReview();
    }
  }

  /// TitleView 진입 시, 첫 실행 3일 경과 후 인앱 리뷰 팝업 요청.
  /// 1회만 호출.
  static Future<void> maybeRequestReviewOnTitleIfEligible() async {
    if (!_isSupported) return;
    if (StorageHelper.readBool(StorageKeys.reviewRequestedOnTitle)) return;
    if (StorageHelper.readBool(StorageKeys.reviewRequestedAfterFirstClear)) return;

    final firstLaunchStr = StorageHelper.read<String>(StorageKeys.firstLaunchDate);
    if (firstLaunchStr == null) return;

    final firstLaunch = DateTime.tryParse(firstLaunchStr);
    if (firstLaunch == null) return;

    final daysSinceLaunch = DateTime.now().difference(firstLaunch).inDays;
    if (daysSinceLaunch < reviewDaysAfterFirstLaunch) return;

    StorageHelper.write(StorageKeys.reviewRequestedOnTitle, true);

    if (await _instance.isAvailable()) {
      _instance.requestReview();
    }
  }

  /// 스토어 리뷰 화면으로 이동. 설정의 "평점 남기기" 버튼에서 호출.
  /// appStoreId가 비어 있으면 false 반환 → 호출자가 SnackBar 표시.
  /// (패키지가 appStoreId null을 허용하지 않아, 비어 있으면 호출하지 않음)
  /// null: 미지원 플랫폼(웹 등), false: appStoreId 비어 있음, true: 성공.
  static Future<bool?> openStoreListing() async {
    if (!_isSupported) return null;
    if (AppConfig.appStoreId.isEmpty) return false;

    await _instance.openStoreListing(appStoreId: AppConfig.appStoreId);
    return true;
  }
}
