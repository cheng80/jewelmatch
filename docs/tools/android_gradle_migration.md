# Android Gradle 설정 메모

기준일: 2026-06-16  
대상 앱: Stone Match (`com.cheng80.stonematch`)

이 문서는 이전 Flutter Android 템플릿에서 현재 Stone Match Android 설정으로 맞출 때 확인할 기준값을 정리한다. 현재 저장소는 이미 Kotlin DSL 기반이다.

## 현재 값

| 항목 | 현재 설정 |
|------|-----------|
| Android Gradle Plugin | `8.11.1` (`android/settings.gradle.kts`) |
| Gradle wrapper | `8.14` (`android/gradle/wrapper/gradle-wrapper.properties`) |
| Kotlin Android plugin | `2.2.20` |
| Java | `17` (`android/app/build.gradle.kts`) |
| namespace | `com.cheng80.stonematch` |
| applicationId | `com.cheng80.stonematch` |

AGP 8.11 계열 공식 호환성은 Gradle 8.13 이상과 JDK 17 기준이다. Stone Match는 Gradle 8.14와 Java 17을 쓰므로 이 범위에 있다.

## 파일별 역할

| 파일 | 역할 |
|------|------|
| `android/settings.gradle.kts` | Flutter Gradle plugin include, AGP/Kotlin plugin 버전 관리 |
| `android/build.gradle.kts` | 공통 repository와 build directory 설정 |
| `android/app/build.gradle.kts` | 앱 namespace, applicationId, SDK, Java/Kotlin target, 서명 설정 |
| `android/gradle/wrapper/gradle-wrapper.properties` | Gradle 배포판 버전 |

## 변경 시 체크리스트

1. `namespace`와 `applicationId`는 둘 다 `com.cheng80.stonematch`로 유지한다.
2. Kotlin `MainActivity.kt`의 package도 `com.cheng80.stonematch`와 맞춘다.
3. AGP를 올릴 때는 Gradle wrapper, JDK 요구사항, Flutter stable 호환성을 함께 확인한다.
4. Android SDK가 이 로컬 환경에는 없으므로 Android 빌드는 SDK 설치 환경에서 별도 검증한다.

## 검증 명령

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

릴리즈 서명 검증은 [`../release/release_build.md`](../release/release_build.md)를 따른다.

## 공식 참고

- Android Gradle Plugin 8.11 release notes: https://developer.android.com/build/releases/agp-8-11-0-release-notes
- Gradle compatibility matrix: https://docs.gradle.org/current/userguide/compatibility.html
