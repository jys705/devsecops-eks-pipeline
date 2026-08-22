# main 브랜치 규칙

저장소 설정을 파일로 기록한다.
화면은 Settings → Rules → Rulesets에 있다.

## 룰셋을 둘로 나눈 이유

GitHub은 PR 저자가 자기 PR을 승인하는 것을 설정과 무관하게 막는다. 운영자가
한 명인 이 저장소에서 승인 한 건을 조건으로 걸면 본인이 연 PR은 머지할 수
없다. 그렇다고, 룰셋 하나에 bypass를 걸면 승인뿐 아니라 검사 게이트까지 함께 열린다.

그래서 검사와 승인을 다른 룰셋에 뒀다. `main-gate`는 bypass 대상이 없어
관리자도 통과하지 못하고, `main-review`만 Repository admin이 bypass한다.
개인 계정 저장소에는 Rule Insights 화면이 없어 bypass 이력을 따로 조회할 수
없다. 승인 없이 머지된 사실은 해당 PR의 Reviewers가 비어 있는 것으로 남는다.

## main-gate

PR을 거치지 않은 main 변경을 막고, 검사 여덟 개와 code scanning 결과를
머지 조건으로 건다. 브랜치가 main보다 뒤처져 있으면 머지하지 못한다.
force push와 브랜치 삭제를 막고 이력을 선형으로 유지한다.

required로 지정한 검사는 실제로 검사를 수행하는 여덟 개다.

    checkov (terraform-infra)
    checkov (terraform-bootstrap)
    checkov (github-actions)
    checkov (dockerfile)
    codeql (actions)
    codeql (python)
    plan
    image (scan)

`image` 워크플로의 `push` 잡은 넣지 않았다. `github.event_name == 'push'`
조건 때문에 어차피 main에 머지된 뒤에 도는 잡이기 때문이다.

체크 이름은 잡 이름 문자열로 지정된다. 룰셋을 만든 뒤에 잡 이름을 바꾸면
그 이름의 체크가 다시는 보고되지 않아 모든 PR이 대기 상태로 잠긴다.

## code scanning 임계값

CodeQL, Checkov, Trivy 셋을 required tool로 지정하고 Alerts와
Security alerts를 모두 All로 뒀다. 기본값은 Only errors와 High or higher다.

임계값을 두지 않은 이유는 CI 단계에서 막히는 것의 되돌리는 비용이 0이기
때문이다. 고쳐서 다시 push하면 된다. 운영 단계의 차단과 조치 비용이 다르다.

이 규칙은 required status checks와 다른 기제다. Checkov는 결함을 찾으면
잡 자체가 실패해 체크가 빨개지지만, CodeQL은 알림만 올리고 잡은 성공한다.
이 규칙이 없으면 CodeQL이 찾은 결함은 머지를 막지 못한다.

한계가 하나 있다. 알림이 지목한 코드 줄이 전부 PR diff 안에 있어야 이
규칙이 동작한다. main에 이미 있는 알림은 그 줄을 건드리지 않는 PR을 막지
않는다.

## main-review

승인 한 건을 조건으로 걸고, 새 커밋이 올라오면 기존 승인을 무효화한다.
승인받은 코드와 머지되는 코드가 달라지는 것을 막기 위한 것이다.

`Require approval of the most recent reviewable push`는 켜지 않았다.
운영자가 한 명이라 지금은 효과가 없다.

## 확인한 것

code scanning 결과는 도구마다 체크 런이 따로 붙는다. `Code scanning results`
뒤에 CodeQL, Checkov, Trivy가 각각 온다. 이 셋은 required status checks 목록에
없고 `Required` 뱃지도 없다. 결함이 있는 PR에서 required 여덟 개가 전부 통과한
채로 이 중 하나만 실패했고 머지가 막혔다. 두 기제가 다른 줄이라는 것이 화면에
그대로 보인다.

차단은 `github-advanced-security` 봇이 리뷰어로 붙어 승인을 요구하는 방식으로
이뤄진다. 머지 상자에 승인 요구와 알림 건수가 함께 뜬다. 같은 시점에 승인 없이
머지된 PR이 있으므로, 이 승인 요구는 `main-review`가 아니라 봇의 것이다.

Checkov와 Trivy 체크 런은 `No new alerts in code changed by this pull request`로
통과했다. 이 저장소에는 억제된 Checkov 알림이 세 건 있지만 그 줄이 PR diff에
없어서 판정에 들어오지 않았다.

`Require branches to be up to date before merging`은 처음에 꺼진 채로 저장돼
있었다. 검사 여덟 개가 전부 초록으로 돌았기 때문에 그동안 드러나지 않았고,
main보다 뒤처진 PR이 생기고 나서야 배너가 없다는 것으로 알았다. 설정 하나가
빠진 것은 그 설정이 판정할 상황이 와야 드러난다. 그래서 화면을 훑는 대신
`gh api`로 룰셋을 받아 규칙 여섯 개와 각 값을 출력으로 대조했다.

번외: `CKV_AWS_149`와 `CKV2_AWS_57`을 `.checkov.yml`의 `skip-check`에 근거와 함께 적었다. 
인라인 `#checkov:skip` 주석으로 먼저 시도했는데, 로컬 스캔은 `Skipped checks: 2`로
세고 checkov 잡은 통과했으며 SARIF의 두 결과에 `suppressions`가 `accepted`로 실렸고 code
scanning 알림 테이블에는 두 건이 만들어지지도 않았다. 그런데도 머지 보호는 그 PR의 분석에
실린 결과 개수를 세어 차단했다. 닫을 알림이 없어 `Dismiss alert`로 풀 수 없었다. 임계값을
`Only errors`로 내리면 풀리지만 Warning 등급을 통과시키게 되어 쓰지 않았다. `skip-check`는
전역이라 그 체크가 모든 파일에서 돌지 않고, 예외가 코드 옆이 아니라 설정 파일에 놓인다.

`bootstrap/kms.tf`의 인라인 셋은 그대로 둔다. 어차피 그 줄이 앞으로 PR 변경분에 들어가지 않아
머지 보호가 판정할 상황이 오지 않는다. 인라인 억제가 통해서가 아니라 판정 대상이 되지
않기 때문이다.

구현이 끝난 뒤 `.github/dependabot.yml`의 생태계 셋에 `open-pull-requests-limit: 0`을
추가해 갱신 pull request 생성을 중단했다. 저장소가 생성했던 AWS 리소스를 전부 제거해
OIDC 프로바이더와 CI 역할이 계정에 없고, `plan` 잡이 수임에 실패해 어떤 pull request도
머지할 수 없기 때문이다. Settings에는 version updates를 끄는 토글이 없고 그 항목은
`Configure` 버튼으로 이 파일을 열 뿐이므로, 중단 여부가 저장소 안에 기록으로 남는다.

Dependabot alerts는 활성 상태로 두었다. 새 결함은 Security 탭에 계속 누적되고 pull
request만 생성되지 않는다. security updates와 grouped security updates는 비활성
상태이며 그 항목들도 pull request를 생성하지 않는다.