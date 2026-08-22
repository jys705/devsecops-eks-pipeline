# 보안 정책

이 저장소는 구현 과정을 기록하기 위해 작성했고 운영 중인 서비스는 없다. 저장소가 생성했던
AWS 리소스는 전부 제거되어 있으므로, 보고할 수 있는 것은 코드와 설정에 포함된 결함이다.

## 저장소에 자격 증명을 포함하지 않는 방법

액세스 키를 생성하지 않는다. 사람은 IAM Identity Center로 로그인하고, CI는 OIDC로 역할을
수임한다. 저장소와 GitHub Actions 시크릿 어느 쪽에도 장기 자격 증명이 없다.

Terraform state를 저장할 버킷 이름과 KMS 키 ARN은 `infra/backend.hcl`에 있고 이 파일은
`.gitignore` 대상이다. `*.tfvars`와 `bootstrap/terraform.tfstate`도 같다. Secrets Manager에 저장하는 값은 apply 시점에 환경변수로만 주입하며, write-only 인자를 사용해 state 파일에 기록되지 않게 했다.

GitHub의 push protection을 활성화해 두었다. 자격 증명 형태의 문자열이 포함된 커밋은 push
단계에서 차단된다.

## 계정 ID 공개

AWS 계정 ID가 커밋 이력과 Actions 로그, 문서에 등장한다. 코드에 하드코딩하지 않고
`data.aws_caller_identity`로 조회하지만, 공개 저장소의 Actions 로그가 공개되므로 완전히
제외할 수는 없다. AWS가 계정 ID를 자격 증명으로 취급하지 않는 점과, 이 저장소의 목표가 저장소
코드에 하드코딩을 하지 않는 것을 서술한다.

## 결함 보고

GitHub Security Advisories의 비공개 보고 기능을 사용한다. 저장소 상단의 Security 탭에서
`Report a vulnerability`로 접근한다. 공개 issue로 보고하지 않는다.

저장소를 보관 상태로 전환한 이후에는 issue와 pull request, 비공개 보고를 생성할 수 없다.
그 시점의 코드는 실행 중인 시스템에 반영되지 않으므로 즉시 조치가 필요한 대상이 아니다.

## 이미 확인된 한계

이 구성이 채택하지 않은 통제와 그 근거는 각 파일의 주석과 `.checkov.yml`, 그리고 블로그
시리즈에 기록되어 있다. 도구가 지적했으나 적용하지 않기로 판단한 항목은 `.checkov.yml`의
`skip-check` 목록과 Security 탭에서 `Won't fix`로 종료한 알림에 근거와 함께 남아 있다.

<https://itcase.tistory.com/entry/devsecops-00>