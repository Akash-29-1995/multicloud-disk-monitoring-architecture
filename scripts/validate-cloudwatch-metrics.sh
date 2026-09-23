#!/usr/bin/env bash
# Live validation against YOUR AWS account.
# Polls CloudWatch until disk metrics appear (wait + retry), then PASS/FAIL.
#
# Usage:
#   ./scripts/validate-cloudwatch-metrics.sh --instance-id i-0123456789abcdef0
#   ./scripts/validate-cloudwatch-metrics.sh --instance-id i-0123 --region us-east-1 --timeout 300

set -euo pipefail

INSTANCE_ID=""
REGION="${AWS_REGION:-us-east-1}"
NAMESPACE="CWAgent"
METRIC="disk_used_percent"
TIMEOUT=300
INTERVAL=20
PROFILE="${AWS_PROFILE:-}"

ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; exit 1; }
info() { echo "[INFO] $*"; }

usage() {
  cat <<EOF
Usage: $0 --instance-id i-xxxxxxxx [--region us-east-1] [--timeout 300] [--profile NAME]

Polls CloudWatch GetMetricStatistics for ${METRIC} until a datapoint exists
or timeout. This is output-based proof that enrollment worked end-to-end.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --instance-id) INSTANCE_ID="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

[[ -n "$INSTANCE_ID" ]] || { usage; exit 1; }

AWS=(aws --region "$REGION")
if [[ -n "$PROFILE" ]]; then
  AWS+=(--profile "$PROFILE")
fi

if ! command -v aws >/dev/null 2>&1; then
  fail "AWS CLI not found. Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
fi

info "Started $(ts) — waiting up to ${TIMEOUT}s for ${METRIC} on ${INSTANCE_ID}"

# Pre-checks
info "Checking STS identity..."
if ! "${AWS[@]}" sts get-caller-identity >/tmp/lucidity-sts.json 2>/tmp/lucidity-sts.err; then
  fail "sts get-caller-identity failed. Configure credentials (aws configure / SSO). $(cat /tmp/lucidity-sts.err)"
fi
pass "AWS credentials work: $(python3 -c "import json; print(json.load(open('/tmp/lucidity-sts.json'))['Arn'])" 2>/dev/null || cat /tmp/lucidity-sts.json)"

info "Checking SSM managed status..."
SSM_OUT="$("${AWS[@]}" ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=${INSTANCE_ID}" \
  --query 'InstanceInformationList[0].PingStatus' \
  --output text 2>/dev/null || echo "None")"

if [[ "$SSM_OUT" == "Online" ]]; then
  pass "SSM PingStatus=Online for ${INSTANCE_ID}"
else
  echo "[WARN] SSM PingStatus=${SSM_OUT} (expected Online). Enrollment may fail; metrics might still exist if agent was configured earlier."
fi

START_EPOCH=$(($(date +%s) - 3600))
END_EPOCH=$(date +%s)
DEADLINE=$(( $(date +%s) + TIMEOUT ))
ATTEMPT=0

while [[ $(date +%s) -lt $DEADLINE ]]; do
  ATTEMPT=$((ATTEMPT + 1))
  END_EPOCH=$(date +%s)
  START_ISO=$(date -u -r "$START_EPOCH" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "@$START_EPOCH" +"%Y-%m-%dT%H:%M:%SZ")
  END_ISO=$(date -u -r "$END_EPOCH" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "@$END_EPOCH" +"%Y-%m-%dT%H:%M:%SZ")

  # List metrics for this instance (dimensions vary by fstype/path)
  METRICS_JSON="$("${AWS[@]}" cloudwatch list-metrics \
    --namespace "$NAMESPACE" \
    --metric-name "$METRIC" \
    --dimensions "Name=InstanceId,Value=${INSTANCE_ID}" \
    --output json 2>/tmp/lucidity-cw.err || echo '{"Metrics":[]}')"

  COUNT=$(python3 -c "import json,sys; print(len(json.load(sys.stdin).get('Metrics',[])))" <<<"$METRICS_JSON" 2>/dev/null || echo 0)

  if [[ "$COUNT" -gt 0 ]]; then
    pass "Found ${COUNT} ${METRIC} metric stream(s) for ${INSTANCE_ID}"
    echo "$METRICS_JSON" | python3 -c "import json,sys; ms=json.load(sys.stdin).get('Metrics',[]);
[print('  dimensions:', {d['Name']:d['Value'] for d in m.get('Dimensions',[])}) for m in ms[:5]]" 2>/dev/null || true

    # Fetch a statistic sample from first matching metric
    STATS="$("${AWS[@]}" cloudwatch get-metric-statistics \
      --namespace "$NAMESPACE" \
      --metric-name "$METRIC" \
      --dimensions "Name=InstanceId,Value=${INSTANCE_ID}" \
      --start-time "$START_ISO" \
      --end-time "$END_ISO" \
      --period 300 \
      --statistics Average \
      --output json 2>/dev/null || echo '{}')"

    DP=$(python3 -c "import json,sys; print(len(json.load(sys.stdin).get('Datapoints',[])))" <<<"$STATS" 2>/dev/null || echo 0)
    if [[ "$DP" -gt 0 ]]; then
      AVG=$(python3 -c "import json,sys; d=json.load(sys.stdin).get('Datapoints',[]); print(round(sorted(d,key=lambda x:x['Timestamp'])[-1]['Average'],2))" <<<"$STATS" 2>/dev/null || echo "?")
      pass "Datapoint received — latest ${METRIC} Average ≈ ${AVG}%"
      pass "End-to-end disk monitoring path is working"
      echo "[INFO] Finished $(ts) after ${ATTEMPT} attempt(s)"
      exit 0
    else
      info "Metric listed but no datapoints yet (attempt ${ATTEMPT}) — waiting ${INTERVAL}s..."
    fi
  else
    info "No ${METRIC} for ${INSTANCE_ID} yet (attempt ${ATTEMPT}) — waiting ${INTERVAL}s..."
  fi
  sleep "$INTERVAL"
done

fail "Timed out after ${TIMEOUT}s waiting for ${METRIC} on ${INSTANCE_ID}. Re-run enroll-disk-monitoring.yml, confirm instance profile has CloudWatchAgentServerPolicy, then see docs/05-troubleshooting.md#metrics-missing"
