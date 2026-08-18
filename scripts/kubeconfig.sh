#!/usr/bin/env bash
# 터널을 사용하도록 kubeconfig를 구성한다. tunnel.sh 를 먼저 실행한다.
# server 를 localhost 로 바꾸면 EKS API 서버의 인증서 이름과 어긋나므로
# tls-server-name 에 원래 엔드포인트 호스트명을 지정한다.
# insecure-skip-tls-verify 는 사용하지 않는다. 검증 자체를 비활성화하면
# 터널의 반대편이 실제로 EKS API 서버인지 확인하지 않게 된다.
#
# 사용법: scripts/kubeconfig.sh [--with-readonly]
set -euo pipefail

CLUSTER="${P2_CLUSTER:-p2-devsecops}"
REGION="${P2_REGION:-ap-northeast-2}"
PROFILE="${P2_PROFILE:-p2-release}"
READONLY_PROFILE="${P2_READONLY_PROFILE:-p2-change}"
LOCAL_PORT="${P2_LOCAL_PORT:-8443}"

WITH_READONLY=false
if [ "${1:-}" = "--with-readonly" ]; then
  WITH_READONLY=true
fi

aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" --profile "$PROFILE"

if [ "$WITH_READONLY" = true ]; then
  aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" \
    --profile "$READONLY_PROFILE" \
    --alias "$READONLY_PROFILE" --user-alias "$READONLY_PROFILE"
fi

ARN=$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.arn' \
  --output text --profile "$PROFILE" --region "$REGION")
EKS_HOST=$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.endpoint' \
  --output text --profile "$PROFILE" --region "$REGION" | sed 's|https://||')

kubectl config set-cluster "$ARN" \
  --server="https://localhost:$LOCAL_PORT" \
  --tls-server-name="$EKS_HOST"
kubectl config use-context "$ARN"

echo
kubectl config current-context