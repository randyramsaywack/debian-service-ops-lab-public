#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  new-debian-vm.sh <vmid> <name> [options]

Create a new Debian VM from the Proxmox template used in this lab.

This helper always creates full clones.

Required arguments:
  vmid                  Target VMID for the cloned VM
  name                  Target VM name / hostname label in Proxmox

Options:
  --template <vmid>     Template VMID to clone from (default: 9002)
  --final-size <size>   Final disk size, not growth amount (default: 20G)
  --ciuser <user>       Cloud-init user (default: debian)
  --cores <count>       vCPU count override
  --memory <mb>         Memory in MB override
  --dhcp                Set ipconfig0 to DHCP (default behavior)
  --ip <cidr>           Set a static IPv4/CIDR on ipconfig0
  --gw <gateway>        Gateway for use with --ip
  --sshkey <path>       Additional public key file path to inject alongside the defaults
  --start               Start the VM after configuration
  -h, --help            Show this help

Examples:
  new-debian-vm.sh 9101 debian12-app01 --start
  new-debian-vm.sh 9102 ops-dev --final-size 32G --cores 4 --memory 4096 --start
  new-debian-vm.sh 9103 ops-stage --ip 10.0.0.20/24 --gw 10.0.0.1 --sshkey /root/ops-lab-sshkey.pub --start
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

require_command qm

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

VMID="$1"
NAME="$2"
shift 2

TEMPLATE_VMID="9002"
FINAL_SIZE="20G"
CIUSER="debian"
CORES=""
MEMORY=""
START_VM=0
IPCONFIG0="ip=dhcp"
SSHKEY_PATH=""
DEFAULT_SSHKEY_PATHS=(
  "/root/.ssh/admin-bootstrap.pub"
  "/root/bin/admin-workstation.pub"
)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --template)
      TEMPLATE_VMID="$2"
      shift 2
      ;;
    --final-size)
      FINAL_SIZE="$2"
      shift 2
      ;;
    --ciuser)
      CIUSER="$2"
      shift 2
      ;;
    --cores)
      CORES="$2"
      shift 2
      ;;
    --memory)
      MEMORY="$2"
      shift 2
      ;;
    --dhcp)
      IPCONFIG0="ip=dhcp"
      shift
      ;;
    --ip)
      STATIC_IP="$2"
      shift 2
      if [[ $# -lt 2 || "$1" != "--gw" ]]; then
        echo "--ip requires a following --gw <gateway>" >&2
        exit 1
      fi
      GATEWAY="$2"
      IPCONFIG0="ip=${STATIC_IP},gw=${GATEWAY}"
      shift 2
      ;;
    --sshkey)
      SSHKEY_PATH="$2"
      shift 2
      ;;
    --start)
      START_VM=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

SSHKEY_FILES=()

for key_path in "${DEFAULT_SSHKEY_PATHS[@]}"; do
  if [[ ! -f "$key_path" ]]; then
    echo "SSH public key file not found: $key_path" >&2
    exit 1
  fi
  SSHKEY_FILES+=("$key_path")
done

if [[ -n "$SSHKEY_PATH" ]]; then
  if [[ ! -f "$SSHKEY_PATH" ]]; then
    echo "SSH public key file not found: $SSHKEY_PATH" >&2
    exit 1
  fi
  SSHKEY_FILES+=("$SSHKEY_PATH")
fi

if qm config "$VMID" >/dev/null 2>&1; then
  echo "Target VMID already exists: $VMID" >&2
  exit 1
fi

echo "Cloning template ${TEMPLATE_VMID} to VM ${VMID} (${NAME}) as a full clone..."
qm clone "$TEMPLATE_VMID" "$VMID" --name "$NAME" --full 1

echo "Resizing disk to final size ${FINAL_SIZE}..."
qm resize "$VMID" scsi0 "$FINAL_SIZE"

echo "Applying cloud-init defaults..."
qm set "$VMID" --ciuser "$CIUSER" --ipconfig0 "$IPCONFIG0"

if [[ -n "$CORES" ]]; then
  qm set "$VMID" --cores "$CORES"
fi

if [[ -n "$MEMORY" ]]; then
  qm set "$VMID" --memory "$MEMORY"
fi

COMBINED_SSHKEY_FILE="$(mktemp)"
trap 'rm -f "$COMBINED_SSHKEY_FILE"' EXIT

cat "${SSHKEY_FILES[@]}" | awk '!seen[$0]++' > "$COMBINED_SSHKEY_FILE"

echo "Injecting SSH keys from:"
printf '  - %s\n' "${SSHKEY_FILES[@]}"
qm set "$VMID" --sshkey "$COMBINED_SSHKEY_FILE"

echo "Resulting configuration:"
qm config "$VMID"

if [[ "$START_VM" -eq 1 ]]; then
  echo "Starting VM ${VMID}..."
  qm start "$VMID"
fi
