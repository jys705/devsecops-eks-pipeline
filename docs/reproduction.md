# 재현 검증

이 저장소는 AWS 계정에 아무것도 남기지 않는 것을 전제로 한다. 각 단계는 만든 것을 전부
지우고 끝나고, 기록은 저장소와 블로그가 갖는다. 그 전제가 성립하려면 저장소의 코드만으로
전체를 다시 만들 수 있어야 한다. 이 문서는 그것을 한 번 확인한 기록이다.

계정 안의 모든 리소스를 지운 뒤 `terraform apply` 한 번으로
다시 만들어 워크로드가 뜨는 데까지 갔다. 시각은 CloudTrail의 API 호출 기록에서 가져왔다.

## 무엇을 처음 시험했나

지금까지의 destroy는 전부 대상을 좁힌 것이었다. OIDC 프로바이더와 IAM 역할 둘, ECR
리포지터리는 단계 6과 9에서 만든 뒤 세션마다 살려 뒀고, 나머지는 세션이 끝날 때 지웠다.
그래서 여덟 개와 나머지가 한 번의 apply 안에서 함께 만들어진 적이 없다.

세 참조가 이번에 처음 시험됐다. `infra/oidc.tf`가 bootstrap이 만든 KMS 키를
`data.aws_kms_alias`로 읽고, 같은 파일의 push 역할 정책이 `aws_ecr_repository.app.arn`을
참조하며, `infra/eks.tf`가 `data.aws_iam_roles`로 Identity Center가 실체화한 SSO 역할을
찾는다. 셋 다 다른 파일에 있고 의존 방향이 서로 다르다.

## 재현 apply

전체 destroy 뒤 상태는 관리 리소스 0개였다. `terraform state list`에서 `data.`로 시작하는
줄을 뺀 개수가 0이고, IAM 역할과 ECR 리포지터리 조회가 빈 배열이었다. 계정에 남은 것은
bootstrap의 S3 버킷과 KMS 키 둘뿐이었다.

`terraform apply`가 `Plan: 65 to add, 0 to change, 0 to destroy.`를 내고 한 번에 통과했다.
중간에 멈추거나 두 번 돌릴 필요가 없었다. 위의 세 참조가 순서대로 풀렸다는 뜻이다.

CloudTrail이 남긴 시각은 이렇다. VPC와 Secrets Manager 시크릿이 `17:08:26`에 같은 초로
만들어졌다. 시크릿이 VPC에 의존하지 않아 병렬로 돈다. 클러스터 생성 요청이 `17:08:39`,
Access Entry 생성이 `17:16:20`이다. Access Entry는 클러스터 리소스가 완료된 뒤에만
만들어지므로 컨트롤 플레인이 `ACTIVE`가 되기까지 7분 41초를 넘지 않았다. 노드그룹 생성
요청이 `17:16:24`다.

apply 전체의 총 소요 시간은 기록하지 못했다. `time`으로 감쌌으나 출력을 파일로 받지 않았고
터미널 스크롤백에서 잘려 나갔다. 클러스터를 지운 뒤에는 되잴 수 없다. CloudTrail의 리소스별
생성 시각이 그 자리를 대신한다.

## 확인한 상태

클러스터가 `ACTIVE`이고 `endpointPublicAccess`가 `false`였다. 엔드포인트가 공개되지 않은
채로 만들어진다는 것이 코드에서 나온 결과다.

IAM 역할 둘(`p2-devsecops-gha-plan`, `p2-devsecops-gha-push`)이 같은 이름으로 다시 생겼다.
이름이 같아야 GitHub Actions 워크플로가 수정 없이 동작한다. ECR 리포지터리가
`IMMUTABLE`로 만들어졌고, Secrets Manager에 시크릿 하나가 있었다.

## 이미지를 되살릴 때 드러난 것

ECR 리포지터리가 새로 만들어져 비어 있었다. `k8s/deployment.yaml`은 배포할 이미지를 이름으로
고정하지 않고 `scripts/deploy.sh`가 현재 커밋의 태그로 조회하므로, 그 커밋의 이미지가
레지스트리에 있어야 한다.

새 커밋을 만들지 않고 기본 브랜치의 마지막 push에 대한 `image` 워크플로 실행을 다시 돌렸다.
이 재실행 자체가 확인 하나를 겸한다. 새로 만들어진 OIDC 프로바이더와 push 역할로 ECR
업로드가 통과한다는 것은 신뢰 정책의 `sub` 클레임과 정책 안의 ECR ARN 참조가 둘 다 이전과
같게 재현됐다는 뜻이다.

되살린 뒤 리포지터리에 이미지 한 개가 있었고, 태그가
`b8712d42ecdfdce28d8f591dddd897b657533229`로 `git rev-parse HEAD`와 같았다. 다이제스트는
`sha256:0d68622333926a1fb7fe3e7d5ebdd92ce17b12e16132fc6eecef7f3a17274ae4`다.

같은 워크플로를 한 번 더 돌리면 실패한다. 레이어는 전부 올라가고 마지막 매니페스트 단계에서
`tag invalid: The image tag 'b8712d42...' already exists in the 'p2-devsecops-app' repository
and cannot be overwritten because the tag is immutable`로 거부된다. `IMMUTABLE`을 고른 대가가
여기서 드러난다. 되살리기는 한 번만 통한다.

**그 로그가 함께 보여준 것이 더 중요하다.** 레이어가 `Layer already exists`가 아니라 전부
`Pushed`로 찍혔다. 같은 커밋을 다시 빌드했는데 레이어 바이트가 달라졌다는 뜻이다. 이 저장소의
빌드는 재현 가능하지 않다. 빌드 프로버넌스 증명은 이 커밋에서 이 빌드가 나왔다는 것을 말하지,
이 커밋이 항상 같은 바이트를 낸다는 것을 말하지 않는다. 이미지 스캔 잡과 push 잡 사이에
이미지를 tar 아티팩트로 넘긴 이유가 여기서 실물로 확인됐다. 다시 빌드하면 다른 것이 된다.

## 클러스터 배포

SSM 포트 포워딩으로 터널을 열고 kubeconfig의 서버 주소를 로컬로 바꾼 뒤 `scripts/deploy.sh`를
실행했다. 클러스터 엔드포인트가 private이라 이 경로 말고는 `kubectl`이 닿지 않는다.

이 스크립트가 클러스터에서 동작하는 것은 이번이 처음이다. 매니페스트와 스크립트는 앞
단계에서 만들었으나 확인에 클러스터가 필요했고, 확인할 내용이 재현 apply가 실행하는 것과
같아서 이 단계로 미뤄 뒀다.

두 사전 검사가 통과했다. `k8s/`와 `app/`에 커밋되지 않은 변경이 없는지 보는 것과 `HEAD`가
`origin/main`과 같은지 보는 것이다. **뒤쪽은 실패로 드러나지 않는 종류라 통과했다는 사실
자체를 적어 둔다.** 지난 커밋에서 실행하면 그 커밋의 이미지가 레지스트리에 남아 있는 한
스크립트가 실패하지 않고 지난 이미지가 조용히 적용된다.

앞쪽 검사는 일부러 걸어서 거부되는 것도 확인했다. `k8s/`의 파일 하나를 고친 채로 실행하면
커밋되지 않은 변경이 있다는 메시지를 내고 종료한다. 저장소에 없는 것이 클러스터에 들어가는
경로가 실제로 막혀 있다.

`kubectl rollout status`가 성공으로 끝나고 파드가 `1/1 Running`이 됐다. 오른쪽 1이
readinessProbe 통과이고, `readOnlyRootFilesystem`을 건 상태에서 `/tmp`에 붙인 `emptyDir`이
gunicorn을 살렸다는 뜻이다. 배포된 파드의 이미지 참조에 레지스트리 호스트명과 커밋 SHA 태그,
다이제스트가 모두 채워져 있었다. 매니페스트에 커밋된 것은 표식뿐이고 값은 배포 시점에
계산된다.

기동 로그에 `[ERROR]` 줄이 없었다. 직전에 gunicorn을 26.1.0으로 올리면서 control socket이
홈 디렉터리에 쓰려다 읽기 전용 파일시스템에 막혀 에러를 남겼는데, `--no-control-socket`으로
그 기능을 끈 뒤 이 확인을 했다. 컨테이너에서 `--read-only`로 확인한 것과 파드에서
`readOnlyRootFilesystem`으로 확인한 것이 같은 결과를 냈다.

`deploy.sh`와 `kubectl`의 출력을 파일로 받지 않아 원문을 옮기지 못했다. CloudTrail은 AWS API
호출만 남기고 `kubectl` 결과는 남기지 않는다. 클러스터가 사라진 뒤에는 되재현할 수 없다.

## write-only가 재현 뒤에도 성립하는가

시크릿 값을 state에서 빼는 것은 앞 단계에서 확인했으나, 그 결과가 한 번짜리인지 재현
apply에서도 나오는지는 별개다.

재현 뒤 state의 시크릿 버전 속성이 `secret_string`은 `""`, `secret_string_wo`는 `null`,
`has_secret_string_wo`는 `true`, `secret_string_wo_version`은 `1`이었다. 값을 주지 않은 것이
아니라 주고도 저장하지 않았다는 것을 provider가 기록한다.

값은 `TF_VAR_app_secret` 환경변수로만 주입한다. 변수의 기본값이 빈 문자열이라 CI가 값 없이
`terraform plan`을 돌려도 차이가 나지 않는다. 값이 plan에 존재하지 않는다는 것이 그 사실로
드러난다. 재현 apply 전에 이 변수를 export하지 않으면 시크릿이 빈 값으로 만들어진다.

## 지운 뒤

`terraform destroy`가 `65 to destroy`를 냈다. apply의 개수와 같다. 그 사이에 콘솔에서
만들어지거나 지워진 것이 없다는 뜻이다.

지운 뒤 관리 리소스가 0개이고, 종류별 조회가 전부 비어 있었다. EKS 클러스터, 기본이 아닌
VPC, CloudWatch 로그 그룹, CloudTrail 트레일, EBS 스냅샷, Secrets Manager 시크릿, 활성 SSM
세션이 모두 없다. S3에는 `tfstate-453722413421-apne2` 한 줄만 있다.

시크릿 조회는 `--include-planned-deletion`을 켜고 했다. 이 옵션 없이 조회하면 삭제 대기 중인
시크릿이 목록에서 빠져 화면이 깨끗해 보인다. `recovery_window_in_days = 0`이 실제로 먹었는지는
이 옵션을 켜야 확인된다.

프로젝트가 진행되는 동안 상시 유지되는 것은 bootstrap의 S3 버킷과 KMS 키뿐이고, 그것도
시리즈가 끝나면 지운다.