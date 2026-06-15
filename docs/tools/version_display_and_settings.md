# 설정 화면과 타이틀 하단 버전 표시

Stone Match는 Drawer를 쓰지 않는다. 설정 항목은 `SettingView`에 있고, 앱 버전은 **타이틀 화면 하단**의 `TitleVersionFooter`에 표시된다.

## 현재 구조

| 영역 | 파일 | 내용 |
|------|------|------|
| 설정 화면 | `lib/views/setting_view.dart` | 화면 켜짐, 사운드, 평점 남기기, 언어 |
| 설정 섹션 | `lib/views/settings/settings_sections.dart` | Riverpod 구독, 볼륨 draft/commit, RateApp |
| 타이틀 하단 버전 표시 | `lib/views/title/title_version_footer.dart` | `Ver <version>+<buildNumber>` |
| 버전 캐싱 | `lib/views/title_view.dart` | `PackageInfo.fromPlatform()` 결과 캐싱 |

## 버전 관리

`pubspec.yaml`의 `version`이 앱 버전과 빌드 번호의 기준이다.

```yaml
version: 1.0.0+1
```

| 구분 | 예 | 쓰임 |
|------|----|------|
| version name | `1.0.0` | 사용자·스토어 노출 |
| build number | `1` | Android `versionCode`, iOS `CFBundleVersion` |

스토어에 같은 version name으로 다시 올리더라도 build number는 이전 업로드보다 커야 한다.

## 설정 화면 변경 규칙

1. 새 설정은 `SettingsNotifier` 또는 명확한 서비스 계층에 상태를 둔다.
2. 저장소 키는 `lib/app_config.dart`의 `StorageKeys`에 추가한다.
3. UI는 `settings_sections.dart`에 섹션 단위로 배치한다.
4. 다국어 문구는 `assets/translations/*.json`에 동시에 추가한다.
5. 웹 미지원 기능은 `kIsWeb` 분기로 숨긴다. 현재 평점 남기기는 웹에서 숨긴다.

## 타이틀 하단 버전 표시 변경 시 체크

- `package_info_plus` 의존성 유지
- `TitleView._cachedPackageInfo` 캐싱 유지
- 버전 표기가 레이아웃을 밀지 않는지 타이틀 화면에서 확인
- 스토어 릴리즈 전 `pubspec.yaml` 버전 증가 여부 확인
