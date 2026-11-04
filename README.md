# 작은 모험 길드 (임시 이름)

하루에 하나의 작은 현실 모험을 제안하는 오프라인 우선 Android 앱입니다. Flutter/Dart로 만들었습니다. 가입, 광고, 인증과 미완료 불이익은 없습니다.

## 콘텐츠 작성

[lib/guild_content.dart](lib/guild_content.dart)의 `guildGreetings`와 `quests`를 직접 수정합니다. 현재 내용은 화면 확인용 예시입니다. 각 목록은 하나 이상이어야 하며 퀘스트는 `(제목, 설명)` 형식입니다. 공개 후 기존 퀘스트 순서를 바꾸거나 항목을 삭제하면 이미 저장된 오늘의 퀘스트가 바뀔 수 있으므로 기존 목록 뒤에 추가하세요.

## 실행과 빌드

Flutter stable과 Android Studio/Android SDK가 필요합니다. 이 작업 PC에서는 `.tools/flutter/bin/flutter.bat`을 사용할 수 있습니다. Android Studio에서 프로젝트 루트를 열고 Flutter 및 Dart 플러그인을 설정하거나 다음 명령을 실행합니다.

```powershell
.\.tools\flutter\bin\flutter.bat pub get
.\.tools\flutter\bin\flutter.bat test
.\.tools\flutter\bin\flutter.bat run
.\.tools\flutter\bin\flutter.bat build appbundle --release
```

릴리스 번들은 `build/app/outputs/bundle/release/app-release.aab`에 생성됩니다. 임시 패키지 ID는 `com.questapp.littleadventure.little_adventure_guild`입니다. Google Play에 처음 업로드한 뒤에는 앱의 패키지 ID를 변경할 수 없으므로 등록 전에 확인하세요. 앱 이름은 AndroidManifest.xml에서 바꿀 수 있습니다.

## 서명 키

이 PC에서 생성한 업로드 키는 `android/app/upload-key.jks`, 비밀번호 및 설정은 `android/key.properties`에 있습니다. 두 파일은 Git에 포함하지 않습니다. **두 파일을 함께 안전한 별도 장소에 백업하세요.** 추후 앱 업데이트를 같은 업로드 키로 서명해야 합니다. 비밀번호나 키를 공개 저장소에 올리지 마세요.

## 현재 범위

- 퀘스트와 완료 상태는 기기에만 보관됩니다. 기기를 바꾸거나 앱 데이터를 삭제하면 기록이 사라집니다.
- 후원 및 의뢰 제안은 준비 중 화면이며 결제나 외부 폼은 연결되지 않았습니다.
- 로컬 알림과 날씨·위치 기반 추천은 구현하지 않았습니다.
- `store-assets/`의 아이콘과 그래픽은 임시 이미지입니다. 스토어 등록 문안과 최종 콘텐츠도 확인 후 교체하세요.
- 비공개 테스트를 시작하기 전 Play Console의 앱 정보, 테스트 대상, 데이터 보안 및 정책 항목은 실제 앱과 계정 상태에 맞게 직접 작성해야 합니다.

## 골드와 길드 꾸미기

퀘스트 완료·실패는 사용자가 직접 선택하며 별도의 인증은 없습니다. 완료하면 임시로 10 G를 지급합니다. 실패해도 보유 골드는 줄지 않습니다. 하루 결과를 선택한 뒤에는 변경할 수 없습니다. 메뉴의 길드 꾸미기에서 화분(10 G), 깃발(20 G), 등불(30 G)을 구입해 한 번에 하나를 배치하거나 치울 수 있습니다. 골드와 장식은 퀘스트 상태와 함께 기기에 저장되며, 앱 데이터를 삭제하거나 다른 기기로 옮기면 자동으로 복원되지 않습니다. 보상과 가격은 추후 조정할 수 있는 초기값입니다.

## 첫 실행 안내

처음 실행하면 길드주인의 대화로 하루 한 의뢰, 완료·실패 보고, 인증 없는 신뢰 규칙, 골드와 길드 꾸미기를 안내합니다. 모든 이야기를 읽고 모험을 시작하면 완료 상태를 기기에 저장합니다. 앱 데이터를 삭제하면 안내가 다시 표시됩니다. 대사는 `lib/guild_content.dart`의 `guildTutorial`에서 수정할 수 있습니다.
