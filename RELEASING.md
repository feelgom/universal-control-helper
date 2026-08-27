# Release guide

## 최초 설정

저장소의 GitHub Actions secret에 `SPARKLE_PRIVATE_KEY`가 필요합니다. 이 값은 Sparkle EdDSA 개인 키이며 절대로 저장소에 커밋하지 않습니다.

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
   git tag v1.3.1
   git push origin main --tags
   ```

`v*` 태그가 푸시되면 `.github/workflows/release.yml`이 다음 작업을 수행합니다.

- 테스트
- arm64/x86_64 Universal Binary 빌드
- Sparkle 프레임워크 임베드와 코드 서명
- EdDSA 서명된 `appcast.xml` 생성
- ZIP, 체크섬, 앱캐스트와 `install.sh`를 GitHub Release에 업로드

앱의 업데이트 URL은 항상 최신 GitHub Release의 `appcast.xml`을 가리킵니다.
