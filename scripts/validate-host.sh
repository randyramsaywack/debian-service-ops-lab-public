#!/usr/bin/env bash

set -u

usage() {
  cat <<'EOF'
Usage:
  ./scripts/validate-host.sh <host> [--http-url <url>]...
  ./scripts/validate-host.sh <user@host> [--http-url <url>]...

Examples:
  ./scripts/validate-host.sh 10.0.0.10
  ./scripts/validate-host.sh debian@ops-dev
  ./scripts/validate-host.sh debian@10.0.0.10 --http-url http://10.0.0.10/healthz
  ./scripts/validate-host.sh debian@10.0.0.10 --http-url http://10.0.0.10/healthz --http-url http://10.0.0.10/api/healthz
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ "${1:-}" = "" ]; then
  usage
  exit 1
fi

target="$1"
shift

http_urls=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --http-url)
      if [ "${2:-}" = "" ]; then
        printf 'Missing value for --http-url\n' >&2
        exit 1
      fi
      http_urls+=("$2")
      shift 2
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage
      exit 1
      ;;
  esac
done

ssh_opts=(
  -o BatchMode=yes
  -o ConnectTimeout=5
  -o StrictHostKeyChecking=accept-new
)

pass_count=0
fail_count=0

run_remote() {
  ssh "${ssh_opts[@]}" "$target" "$1"
}

record_pass() {
  pass_count=$((pass_count + 1))
  printf 'PASS  %s\n' "$1"
}

record_fail() {
  fail_count=$((fail_count + 1))
  printf 'FAIL  %s\n' "$1"
}

check_command() {
  label="$1"
  command="$2"
  output_file="$(mktemp)"

  if run_remote "$command" >"$output_file" 2>&1; then
    record_pass "$label"
  else
    record_fail "$label"
    sed 's/^/      /' "$output_file"
  fi

  rm -f "$output_file"
}

printf 'Validating host: %s\n' "$target"
printf '\n'

if run_remote "printf connected" >/dev/null 2>&1; then
  record_pass "SSH connectivity"
else
  record_fail "SSH connectivity"
  printf '\nSummary: %s passed, %s failed\n' "$pass_count" "$fail_count"
  exit 1
fi

check_command "sudo available without password prompt" "sudo -n true"
check_command "system state is running or degraded" "state=\$(systemctl is-system-running); [ \"\$state\" = running ] || [ \"\$state\" = degraded ]"
check_command "no failed systemd units" "! systemctl --failed --no-legend | grep -q ."
check_command "qemu-guest-agent service is active" "systemctl is-active --quiet qemu-guest-agent"
check_command "ufw is active" "sudo ufw status | grep -q '^Status: active\$'"
check_command "ufw allows SSH on tcp/22" "sudo ufw status | grep -Eq '(^| )22/tcp[[:space:]]+ALLOW'"
check_command "fail2ban sshd jail is available" "sudo fail2ban-client status sshd >/dev/null"
check_command "reboot is not required" "[ ! -f /var/run/reboot-required ]"

for http_url in "${http_urls[@]}"; do
  check_command "HTTP endpoint returns success: $http_url" "curl -fsS --max-time 5 '$http_url' >/dev/null"
done

printf '\nSummary: %s passed, %s failed\n' "$pass_count" "$fail_count"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
