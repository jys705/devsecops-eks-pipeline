#!/usr/bin/env bash
# EKS API 서버로 향하는 SSM 포트 포워딩 터널을 연다.
# 클러스터 엔드포인트가 private이라 로컬 kubectl이 직접 도달하지 못하므로,
# 워커 노드를 경유하는 터널을 만들고 kubectl은 localhost로 연결한다.
# 이 스크립트는 종료되지 않는다. 다른 터미널에서 kubectl을 실행하고,
# 작업이 끝나면 Ctrl+C로 세션을 종료한다.
set -euo pipefail

CLUSTER="${P2_CLUSTER:-p2-devsecops}"
REGION="${P2_REGION:-ap-northeast-2}"
PROFILE="${P2_PROFILE:-p2-release}"
LOCAL_PORT="${P2_LOCAL_PORT:-8443}"

if lsof -nP -iTCP:"$LOCAL_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "포트 $LOCAL_PORT 가 이미 사용 중이다. 이전 세션이 남아 있는지 확인한다." >&2
  exit 1
fi

NODE=$(aws ec2 describe-instances \
  --filters "Name=tag:eks:cluster-name,Values=$CLUSTER" \
            "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" --output text \
  --profile "$PROFILE" --region "$REGION")

if [ "$NODE" = "None" ] || [ -z "$NODE" ]; then
  echo "실행 중인 워커 노드가 없다. 클러스터가 생성되어 있는지 확인한다." >&2
  exit 1
fi

EKS_HOST=$(aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.endpoint' --output text \
  --profile "$PROFILE" --region "$REGION" | sed 's|https://||')

echo "node     : $NODE"
echo "endpoint : $EKS_HOST"
echo "local    : https://localhost:$LOCAL_PORT"
echo

PARAMS=$(printf '{"host":["%s"],"portNumber":["443"],"localPortNumber":["%s"]}' \
  "$EKS_HOST" "$LOCAL_PORT")

exec aws ssm start-session \
  --target "$NODE" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "$PARAMS" \
  --profile "$PROFILE" --region "$REGION"