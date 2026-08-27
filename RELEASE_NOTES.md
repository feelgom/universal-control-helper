# Universal Control Helper 1.5.3

- Universal Control로 입력이 Target에 전달될 때 Source의 입력 소스 변경 알림이 발생하지 않아 Caps Lock이 동작하지 않던 v1.5.0 회귀를 수정했습니다.
- Source에서 물리 Caps Lock을 다시 감지하되 키 입력은 차단하지 않고 Target에 전환 신호만 전달합니다.
- 새 버전끼리는 Source의 ABC/두벌식 상태 동기화도 함께 사용해 두 Mac의 상태가 어긋난 경우 자동으로 바로잡습니다.
- 구버전 Target에는 상태 메시지를 중복 전송하지 않아 Caps Lock이 두 번 전환되는 문제를 방지합니다.
- 입력 모니터링 권한은 키보드가 연결된 Source Mac에만 필요하며 Target에는 필요하지 않습니다.
- 기존 ad-hoc 빌드의 권한 스위치가 켜져 있어도 현재 빌드가 미허용인 경우를 위해 Source 설정에 **권한 항목 재등록…** 복구 동작을 추가했습니다.
- 권한 항목 재등록 후 macOS 입력 모니터링 승인 요청을 위해 Core Graphics 권한 요청을 함께 사용합니다.
- 권한 목록에 앱이 자동으로 나타나지 않는 macOS 환경을 위해 직접 추가하는 안내와 **앱 위치 보기**를 제공합니다.
