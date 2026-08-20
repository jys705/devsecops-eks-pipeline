# main 브랜치 규칙

저장소 설정을 파일로 기록한다.
화면은 Settings → Rules → Rulesets에 있다.

## 룰셋을 둘로 나눈 이유

GitHub은 PR 저자가 자기 PR을 승인하는 것을 설정과 무관하게 막는다. 운영자가
한 명인 이 저장소에서 승인 한 건을 조건으로 걸면 본인이 연 PR은 머지할 수
없다. 그렇다고, 룰셋 하나에 bypass를 걸면 승인뿐 아니라 검사 게이트까지 함께 열린다.

그래서 검사와 승인을 다른 룰셋에 뒀다. `main-gate`는 bypass 대상이 없어
관리자도 통과하지 못하고, `main-review`만 Repository admin이 bypass한다.
bypass 기록은 Rule Insights에 건별로 남는다.

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