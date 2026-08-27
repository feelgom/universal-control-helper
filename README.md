# UniInput Fix

Universal Control로 다른 Mac을 조작할 때 Caps Lock 한/영 전환이 동작하지 않는 문제를 보정하는 macOS 메뉴 막대 앱입니다.

> 휠 스크롤 문제는 구형 Logi Options 삭제로 해결되었으므로, 버전 1.1부터 마우스 감시와 스크롤 릴레이 기능을 완전히 제거했습니다.

## 주요 기능

- Source Mac에서 물리 키보드의 Caps Lock 누름만 감지
- Bonjour를 이용한 Target Mac 자동 검색
- 6자리 페어링 코드가 일치하는 Mac만 명령 처리
- Target Mac의 현재 입력 소스를 확인해 `ABC ↔ 두벌식` 직접 전환
- Sparkle을 통한 새 버전 자동 확인과 안전한 인앱 업데이트

일반 키 입력, 입력한 텍스트, 마우스 이벤트는 읽거나 전송하지 않습니다. 외부 서버도 사용하지 않습니다.

## 요구 사항

- macOS 13 이상
- 같은 로컬 네트워크에 연결된 두 Mac
- 두 Mac 사이에 정상적으로 설정된 Universal Control

## 설치 및 사용

1. [최신 Release](https://github.com/feelgom/UniInputFix/releases/latest)에서 `UniInputFix-macOS-universal.zip`을 받습니다.
2. 압축을 풀어 `UniInputFix.app`을 두 Mac의 `/Applications`로 복사합니다.
3. 키보드가 연결된 Mac에서는 **키보드 Mac (Source)**로 둡니다.
4. 조작할 다른 Mac에서는 **대상 Mac (Target)**을 선택합니다.
5. 두 Mac의 `페어링 코드`를 같은 6자리 숫자로 맞춥니다.
6. Source Mac에서는 **시스템 설정 → 개인정보 보호 및 보안**에서 앱의 **접근성**과 **입력 모니터링**을 허용합니다. Target Mac에는 해당 권한이 필요하지 않습니다.
7. Universal Control 포인터가 Target Mac에 있을 때 Source 메뉴의 **Caps Lock 보정 켜기**를 선택합니다. 단축키는 `Control-Option-Command-U`입니다.
8. Source Mac으로 돌아오면 같은 단축키로 보정을 끕니다.

개인 개발자 서명 없이 배포된 빌드는 첫 실행 시 Finder에서 앱을 Control-클릭한 뒤 **열기**를 선택해야 할 수 있습니다.

## 업데이트

앱은 Sparkle을 통해 GitHub Release의 서명된 업데이트 피드를 확인합니다. 메뉴의 **업데이트 확인…**으로 즉시 확인할 수 있으며, 기본적으로 새 버전을 주기적으로 확인합니다.

## 개발

```sh
swift test
./scripts/build-app.sh
```

태그(`v1.2.0` 등)를 푸시하면 GitHub Actions가 테스트, Universal Binary 빌드, Sparkle 서명, 앱캐스트 생성, GitHub Release 업로드를 수행합니다. 자세한 절차는 [RELEASING.md](RELEASING.md)를 참고하세요.

## 보안 및 개인정보

- 네트워크로 전송되는 사용자 동작은 `입력 소스 전환` 명령뿐입니다.
- 입력한 문자와 클립보드는 수집하거나 전송하지 않습니다.
- 업데이트 ZIP은 Sparkle EdDSA 서명으로 검증됩니다.
- 취약점 신고 방법은 [SECURITY.md](SECURITY.md)를 참고하세요.

## 라이선스

[MIT License](LICENSE)
