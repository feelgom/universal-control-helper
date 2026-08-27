<p align="center">
  <img src=".github/assets/hero.svg" alt="Universal Control Helper — keyboard input fixes for macOS Universal Control" width="100%" />
</p>

<h1 align="center">Universal Control Helper</h1>

<p align="center">
  <strong>Universal Control의 키보드 입력 문제를 바로잡습니다.</strong>
  <br />
  <sub>키보드 하나, Mac 두 대, 익숙한 전환 방식 그대로.</sub>
</p>

<p align="center">
  <a href="https://github.com/feelgom/universal-control-helper/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/feelgom/universal-control-helper/ci.yml?branch=main&style=flat-square&label=build"></a>
  <a href="https://github.com/feelgom/universal-control-helper/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/feelgom/universal-control-helper?style=flat-square&color=5b7cfa"></a>
  <a href="https://github.com/feelgom/universal-control-helper/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/feelgom/universal-control-helper?style=flat-square&color=f5c542"></a>
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-31c48d?style=flat-square"></a>
  <img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-111827?style=flat-square&logo=apple">
</p>

<p align="center">
  <a href="#빠른-시작">빠른 시작</a> ·
  <a href="#사용법">사용법</a> ·
  <a href="#어떻게-동작하나요">작동 방식</a> ·
  <a href="#업데이트">업데이트</a> ·
  <a href="#개발">개발</a>
</p>

---

macOS Universal Control로 다른 Mac을 조작할 때 Caps Lock을 눌러도 한/영 전환이 되지 않는 경우가 있습니다. Universal Control Helper는 Source Mac의 `ABC ↔ 두벌식` 변경을 감지하고, Target Mac의 입력 소스를 같은 상태로 맞춥니다. 키보드 이벤트를 직접 읽지 않으므로 입력 모니터링 권한이 필요하지 않습니다.

> Apple과 제휴하거나 Apple이 보증한 제품이 아닌 비공식 오픈 소스 유틸리티입니다.


## 빠른 시작

### 설치 스크립트 — 권장

다음 명령은 최신 GitHub Release를 내려받고, 게시된 SHA-256 체크섬과 앱 서명을 확인한 뒤 `/Applications`에 설치합니다. 기존 설치본은 삭제하지 않고 사용자 Library의 백업 폴더로 이동합니다.

```bash
curl -fsSL https://github.com/feelgom/universal-control-helper/releases/latest/download/install.sh | bash
```

실행 전에 스크립트를 확인하려면:

```bash
curl -fsSL https://github.com/feelgom/universal-control-helper/releases/latest/download/install.sh -o /tmp/universal-control-helper-install.sh
less /tmp/universal-control-helper-install.sh
bash /tmp/universal-control-helper-install.sh
```

앱을 자동 실행하지 않거나 다른 폴더에 설치할 수도 있습니다.

```bash
bash /tmp/universal-control-helper-install.sh --no-launch
bash /tmp/universal-control-helper-install.sh --install-dir "$HOME/Applications"
```

### 직접 설치

[최신 Release](https://github.com/feelgom/universal-control-helper/releases/latest)에서 `UniversalControlHelper-macOS-universal.zip`을 받아 압축을 풀고 `Universal Control Helper.app`을 `/Applications`로 옮깁니다.

> [!IMPORTANT]
> Apple Developer ID가 설정되지 않은 공개 빌드는 임시 서명으로 배포되므로 첫 실행 시 Finder에서 앱을 Control-클릭한 뒤 **열기**를 선택해야 할 수 있습니다. Developer ID 자격 증명이 등록되면 같은 파이프라인이 자동으로 서명·공증된 앱을 배포합니다.

## 사용법

두 Mac에 앱을 설치한 다음 역할과 페어링 코드만 맞추면 됩니다.

| Mac | 역할 | 필요한 권한 | 할 일 |
| --- | --- | --- | --- |
| 키보드가 연결된 Mac | **키보드 Mac (Source)** | 로컬 네트워크 | 자동 생성된 코드 확인 |
| 조작할 다른 Mac | **대상 Mac (Target)** | 로컬 네트워크 | Source의 코드 입력 |

1. 두 Mac을 같은 로컬 네트워크에 연결하고 Universal Control을 활성화합니다.
2. 메뉴 막대의 **설정…** 또는 `Command-,`로 설정창을 엽니다.
3. 키보드가 연결된 Mac은 Source, 다른 Mac은 Target으로 선택합니다.
4. Source에 자동 생성된 **페어링 코드**를 Target에 입력합니다.
5. 첫 연결 때 두 Mac에 나타나는 로컬 네트워크 요청을 허용합니다.

설정창은 일반, 연결, 소프트웨어 업데이트 순서로 구성됩니다. 창이 열려 있을 때 `Command-W`를 누르면 메뉴 막대 앱은 계속 실행되지만 `Command-Tab` 목록에서는 숨겨집니다. 다시 열 때는 메뉴 막대의 **설정…**을 사용합니다. 로컬 네트워크 권한은 첫 연결 때 macOS가 자동으로 요청하므로 별도의 설정 항목으로 표시하지 않습니다. 입력 모니터링과 접근성 권한은 필요하지 않습니다.

메뉴 막대 메뉴에는 전체 기능 스위치, 설정, 종료만 표시합니다. 역할, 페어링 코드, 연결과 업데이트는 설정창에서 관리합니다. 상단 스위치나 설정창의 **Universal Control Helper 사용**을 끄면 입력 소스 동기화와 두 Mac 간 연결이 함께 일시 중지됩니다. **Mac에 로그인할 때 자동으로 실행**을 켜면 별도 헬퍼 없이 macOS 로그인 항목으로 등록됩니다.

## 어떻게 동작하나요?

```text
Source Mac의 ABC/두벌식 변경
             │
             ▼
Source Mac ── Bonjour / 같은 LAN ──▶ Target Mac
 상태 확인        6자리 코드 확인        같은 상태 적용
```

- Source는 키보드 이벤트 대신 macOS가 제공하는 입력 소스 변경 알림만 관찰합니다.
- Caps Lock, 입력 메뉴 또는 다른 단축키로 바꾼 ABC/두벌식 상태가 모두 동기화됩니다.
- Bonjour로 Target을 자동 검색하고, 코드가 일치한 연결만 처리합니다.
- Target은 현재 입력 소스를 확인한 뒤 macOS API로 ABC와 두벌식을 직접 전환합니다.
- 일반 키 입력, 입력한 텍스트, 클립보드, 마우스 이벤트는 수집하거나 전송하지 않습니다.

### 현재 범위

- macOS 13 이상
- `ABC ↔ 두벌식` 조합
- 신뢰할 수 있는 동일 로컬 네트워크
- Source가 실행 중이면 ABC/두벌식 상태 변경을 Target에 자동 전달

페어링 코드는 같은 네트워크의 다른 앱을 구분하는 용도이며 네트워크 암호화를 제공하지 않습니다. 공용·비신뢰 네트워크에서는 사용하지 마세요.

## 업데이트

앱은 [Sparkle](https://sparkle-project.org/)로 GitHub Release의 EdDSA 서명 업데이트를 확인합니다. 설정창의 **소프트웨어 업데이트** 섹션에서 현재 버전을 보거나 **업데이트 확인…**을 선택할 수 있으며, 기본 주기 확인도 지원합니다.

v1.5.0부터 입력 모니터링 권한을 사용하지 않으므로 앱 업데이트 후 해당 권한을 다시 허용할 필요가 없습니다. 임시 서명 빌드에서는 Gatekeeper 안내나 로컬 네트워크 요청이 다시 나타날 가능성을 완전히 배제할 수 없으며, Developer ID를 도입하면 이 앱의 서명 신원도 업데이트 간에 유지됩니다.

## 개발

```bash
swift test -Xswiftc -warnings-as-errors
BUILD_UNIVERSAL=1 ./scripts/build-app.sh
REQUIRE_UNIVERSAL=1 ./scripts/verify-release.sh
```

`v*` 태그를 푸시하면 GitHub Actions가 테스트, Universal Binary 빌드, Sparkle 서명, 앱캐스트 생성과 Release 업로드를 수행합니다. Apple 자격 증명이 있으면 Developer ID 서명과 공증도 자동으로 추가됩니다. 자세한 절차는 [RELEASING.md](RELEASING.md)를 참고하세요.

## Star History

<p align="center">
  <a href="https://www.star-history.com/?repos=feelgom%2Funiversal-control-helper&type=date&legend=top-left">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=feelgom/universal-control-helper&type=date&theme=dark&legend=top-left&sealed_token=FwEg8EPGkwsDKHlbN4MhzmytFu5S0LOeuuX13EWlrAvb6dZKzGz0W7xg_2wxftWukmAlnqMS9DlVzbhB1zmZXNecoFq1n6Y6Mt30B8OCIzTj10uCc3ZKJQ" />
      <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=feelgom/universal-control-helper&type=date&legend=top-left&sealed_token=FwEg8EPGkwsDKHlbN4MhzmytFu5S0LOeuuX13EWlrAvb6dZKzGz0W7xg_2wxftWukmAlnqMS9DlVzbhB1zmZXNecoFq1n6Y6Mt30B8OCIzTj10uCc3ZKJQ" />
      <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=feelgom/universal-control-helper&type=date&legend=top-left&sealed_token=FwEg8EPGkwsDKHlbN4MhzmytFu5S0LOeuuX13EWlrAvb6dZKzGz0W7xg_2wxftWukmAlnqMS9DlVzbhB1zmZXNecoFq1n6Y6Mt30B8OCIzTj10uCc3ZKJQ" />
    </picture>
  </a>
</p>

## 보안 및 기여

- 보안 문제는 공개 Issue 대신 [보안 정책](SECURITY.md)에 안내된 비공개 신고 기능을 이용해 주세요.
- 버그 제보와 개선 제안은 [GitHub Issues](https://github.com/feelgom/universal-control-helper/issues)에서 받습니다.
- 코드는 [MIT License](LICENSE)로 배포됩니다.
