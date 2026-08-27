# Release guide

## 최초 설정

공개 릴리즈는 항상 같은 **Developer ID Application** 인증서로 서명하고 Apple 공증을 통과해야 합니다. Apple Developer Program 가입 후 다음 값을 GitHub의 `release` Environment secret으로 등록합니다.

| Secret | 내용 |
| --- | --- |
| `APPLE_CERTIFICATE_P12` | Developer ID Application 인증서와 개인 키를 내보낸 `.p12`의 Base64 값 |
| `APPLE_CERTIFICATE_PASSWORD` | `.p12`를 내보낼 때 지정한 암호 |
| `APPLE_ID` | Apple Developer 계정 Apple ID |
| `APPLE_APP_SPECIFIC_PASSWORD` | Apple ID에서 생성한 앱 암호 |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `SPARKLE_PRIVATE_KEY` | Sparkle EdDSA 개인 키 |

1. Xcode의 **Settings → Accounts → Manage Certificates**에서 `Developer ID Application` 인증서를 생성합니다.
2. 키체인 접근에서 인증서와 개인 키를 함께 선택해 암호가 설정된 `.p12`로 내보냅니다.
3. GitHub 저장소의 **Settings → Environments → release**를 만들고 필요한 경우 승인 규칙을 설정합니다.
4. 다음처럼 secret을 등록합니다. 실제 값은 셸 기록이나 저장소 파일에 남기지 않습니다.

   ```sh
   base64 -i DeveloperIDApplication.p12 | gh secret set APPLE_CERTIFICATE_P12 --env release
   gh secret set APPLE_CERTIFICATE_PASSWORD --env release
   gh secret set APPLE_ID --env release
   gh secret set APPLE_APP_SPECIFIC_PASSWORD --env release
   gh secret set APPLE_TEAM_ID --env release
   gh secret set SPARKLE_PRIVATE_KEY --env release
   ```

인증서나 공증 값이 하나라도 없으면 Release workflow는 배포 전에 실패합니다. 인증서는 작업 중 생성한 임시 키체인에만 가져오며 작업 종료 시 삭제합니다.

현재 Bundle ID인 `io.yoonsungji.UniInputFix`는 macOS 개인정보 보호 권한의 앱 식별에 사용되므로 변경하지 않습니다. 최초 Developer ID 서명 버전으로 전환할 때 Source Mac에서 입력 모니터링을 한 번 다시 허용해야 할 수 있지만, 이후 같은 Team ID·인증서·Bundle ID로 서명한 업데이트에서는 권한이 유지됩니다.

### 서명·공증 사전 검사

태그를 만들기 전에 Actions의 **Release → Run workflow**를 실행하거나 다음 명령을 사용합니다.

```sh
gh workflow run release.yml --ref main
```

수동 실행은 다음 과정을 실제로 수행하지만 GitHub Release는 만들지 않습니다.

- Developer ID 인증서 가져오기
- Hardened Runtime을 적용한 Universal Binary 및 Sparkle 구성요소 서명
- `notarytool`로 Apple 공증 제출 및 결과 대기
- 공증 티켓 staple 및 Gatekeeper 검사
- 설치 파일을 Actions artifact로 업로드

## 새 버전 배포

1. `Resources/Info.plist`의 `CFBundleShortVersionString`과 `CFBundleVersion`을 같은 버전으로 올립니다.
2. `RELEASE_NOTES.md`를 새 버전 내용으로 갱신합니다.
3. 테스트와 로컬 빌드를 확인합니다.

   ```sh
   swift test -Xswiftc -warnings-as-errors
   BUILD_UNIVERSAL=1 ./scripts/build-app.sh
   REQUIRE_UNIVERSAL=1 ./scripts/verify-release.sh
   ```

4. 버전 커밋에 태그를 만들고 푸시합니다.

   ```sh
   git tag v1.4.1
   git push origin main --tags
   ```

`v*` 태그가 푸시되면 `.github/workflows/release.yml`이 다음 작업을 수행합니다.

- 테스트
- arm64/x86_64 Universal Binary 빌드
- Sparkle 내부 구성요소와 앱을 Developer ID로 안쪽부터 서명
- Hardened Runtime, secure timestamp 적용
- Apple 공증 완료 및 티켓 staple
- Developer ID, 공증 및 Gatekeeper 검증
- EdDSA 서명된 `appcast.xml` 생성
- ZIP, 체크섬, 앱캐스트와 `install.sh`를 GitHub Release에 업로드

앱의 업데이트 URL은 항상 최신 GitHub Release의 `appcast.xml`을 가리킵니다.
