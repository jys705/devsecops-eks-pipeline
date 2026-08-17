# IAM Identity Center 구성

콘솔로 만들고, Terraform으로 관리하지 않는다.

## 권한 세트

| 이름 | 정책 | 세션 기간 | 대응하는 역할 |
|---|---|---|---|
| `ReleaseOperator` | `AdministratorAccess` (AWS 관리형) | 4시간 | PR 리뷰 승인, `terraform apply`, `kubectl` |
| `ChangeOperator` | `ReadOnlyAccess` (AWS 관리형) | 8시간 | 인프라, 매니페스트, 앱 코드 작성, PR 생성 |

두 권한 세트는 각각 별도의 Identity Center 사용자에게 할당한다. 한 사용자가
둘을 들고 있으면 작성자와 승인자가 같은 사람이 되어 역할 분리가 성립하지 않는다.

권한이 큰 쪽의 세션을 비교적 짧게 둔다. `ReleaseOperator`의 4시간은 EKS 생성과 삭제
왕복이 한 세션에 들어가는 최소값이고, `ChangeOperator`는 아무것도 바꿀 수 없어 비용이 낮기 때문에, 세션을 길게 두는 방향을 선택한다.

## Terraform으로 관리하지 않는 이유

권한 세트를 관리하는 Terraform 루트는 `terraform destroy`로 본인 실행에 쓰는
자격 증명을 지울 수 있다. 권한 세트를 지우면 대상 계정의 IAM 역할이 함께
사라지고 이미 발급된 세션도 무효가 되므로, 그 destroy는 중간에 실패한다.

`bootstrap/`에 넣어도 같은 문제가 생긴다. 별도 루트를 하나 더 두면 피할 수
있지만 state가 셋이 되고, 이 프로젝트에서 권한 세트는 만들고 지우기를 반복하는
대상이 아니다.

## 권한 세트가 IAM 역할이 되는 경로

권한 세트는 정책 묶음이고, 대상 계정에서 `AWSReservedSSO_<권한 세트 이름>_<해시>`
IAM 역할로 실체화된다. 사용자가 로그인하면 그 역할을 수임해 단기 자격 증명을
발급받는다. 권한은 권한 세트에 붙고 자격 증명은 그 결과물이다.

## 저장소에 두지 않는 값

SSO 시작 URL과 Identity Center 인스턴스 ARN, 계정 ID는 계정 고유값이라
`~/.aws/config`에만 둔다. 권한 세트 이름과 정책, 세션 기간은 판단이므로 기록한다.