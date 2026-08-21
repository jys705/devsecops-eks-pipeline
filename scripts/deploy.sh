#!/usr/bin/env bash
# 매니페스트를 클러스터에 적용한다. scripts/tunnel.sh 와 scripts/kubeconfig.sh 를 먼저 실행한다.
#
# 배포할 이미지 참조를 매니페스트에 커밋하지 않는 이유는 순환 때문이다.
# 이미지 태그가 커밋 SHA이고 그 태그를 매니페스트에 적는 것도 커밋이므로,
# 자기가 만든 이미지를 가리키는 커밋은 존재할 수 없다. 참조를 배포 시점에 계산하면
# 체크아웃한 커밋과 클러스터에서 실행 중인 이미지가 항상 같아진다.
set -euo pipefail

REGION="${P2_REGION:-ap-northeast-2}"
PROFILE="${P2_PROFILE:-p2-release}"
REPO="${P2_REPO:-p2-devsecops-app}"
DEPLOYMENT="${P2_DEPLOYMENT:-p2-devsecops-app}"
NAMESPACE="${P2_NAMESPACE:-p2-devsecops}"

cd "$(dirname "$0")/.."

if [ -n "$(git status --porcelain k8s app)" ]; then
  echo "k8s/ 또는 app/ 에 커밋되지 않은 변경이 있다." >&2
  echo "이 스크립트는 저장소에 들어간 것만 적용한다. 로컬 변경은 이미지에 없다." >&2
  echo "되돌리려면 git restore 를 쓴다. 저장소에 반영하는 경로는 PR이고 여기 범위가 아니다." >&2
  exit 1
fi

git fetch --quiet origin main
if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
  echo "HEAD 가 origin/main 과 다르다." >&2
  echo "지난 커밋이나 토픽 브랜치에 있으면 그 커밋의 이미지가 ECR에 남아 있는 한" >&2
  echo "실패하지 않고 지난 이미지가 적용된다." >&2
  echo "git switch main && git pull 로 맞춘 뒤 다시 실행한다." >&2
  exit 1
fi

COMMIT=$(git rev-parse HEAD)
ACCOUNT=$(aws sts get-caller-identity --query Account --output text --profile "$PROFILE")
REGISTRY="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"

if ! DIGEST=$(aws ecr describe-images --repository-name "$REPO" \
      --image-ids "imageTag=$COMMIT" --query 'imageDetails[0].imageDigest' \
      --output text --profile "$PROFILE" --region "$REGION" 2>/dev/null); then
  echo "커밋 $COMMIT 로 빌드된 이미지가 ECR에 없다." >&2
  echo "main 에 머지된 커밋인지, image 잡이 끝났는지 확인한다." >&2
  exit 1
fi

echo "commit   : $COMMIT"
echo "registry : $REGISTRY"
echo "digest   : $DIGEST"
echo

kubectl apply -f k8s/namespace.yaml

sed -e "s|__REGISTRY__|$REGISTRY|" \
    -e "s|__COMMIT__|$COMMIT|" \
    -e "s|__DIGEST__|${DIGEST#sha256:}|" \
    k8s/deployment.yaml | kubectl apply -f -

kubectl rollout status "deploy/$DEPLOYMENT" -n "$NAMESPACE"
echo
kubectl get pod -n "$NAMESPACE" \
  -o jsonpath='{range .items[*]}{.metadata.name}{"  "}{.spec.containers[0].image}{"\n"}{end}'