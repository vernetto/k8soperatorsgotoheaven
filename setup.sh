#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# 100 Shades of Kubernetes — Lab Setup Script
# Usage: ./setup.sh [episode-number]
#   ./setup.sh 5           → apply episode 05 and print the challenge
#   ./setup.sh             → list all available episodes
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ANSI colours
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

print_banner() {
  echo -e "${CYAN}${BOLD}"
  echo "  ╔══════════════════════════════════════════════════════╗"
  echo "  ║       100 Shades of Kubernetes — Inspector Ahmed      ║"
  echo "  ║           Interactive Lab Environment Setup           ║"
  echo "  ╚══════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

list_episodes() {
  echo -e "${BOLD}Available episodes:${RESET}"
  echo ""
  for f in "$SCRIPT_DIR"/episode-*.yaml; do
    ep=$(basename "$f" .yaml)
    # Extract the culprit line
    culprit=$(grep "^# Culprit:" "$f" 2>/dev/null | head -1 | sed 's/^# Culprit: //')
    difficulty=$(grep "^# .*Difficulty:" "$f" 2>/dev/null | head -1 | sed 's/.*Difficulty: //')
    printf "  %-55s %s\n" "${ep}" "${culprit:-}"
  done
  echo ""
}

apply_episode() {
  local ep_num
  ep_num=$(printf "%02d" "$1")
  local manifest
  manifest=$(find "$SCRIPT_DIR" -name "episode-${ep_num}-*.yaml" | head -1)

  if [ -z "$manifest" ]; then
    echo -e "${RED}Episode ${ep_num} not found.${RESET}"
    list_episodes
    exit 1
  fi

  local ep_name
  ep_name=$(basename "$manifest" .yaml)

  echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════${RESET}"
  echo -e "${BOLD}  Applying: ${ep_name}${RESET}"
  echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════${RESET}"
  echo ""

  # Extract metadata from the manifest header
  echo -e "${YELLOW}📋 Scenario Info:${RESET}"
  grep "^# " "$manifest" | head -10 | sed 's/^# /  /'
  echo ""

  echo -e "${GREEN}🚀 Applying manifest...${RESET}"
  kubectl apply -f "$manifest"
  echo ""

  echo -e "${YELLOW}⏳ Waiting 5 seconds for resources to initialise...${RESET}"
  sleep 5
  echo ""

  echo -e "${BOLD}📊 Current cluster state:${RESET}"
  kubectl get pods,deployments,services,pvc,jobs,cronjobs 2>/dev/null \
    | grep -v "^NAME\|^$" || true
  echo ""

  echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════${RESET}"
  echo -e "${BOLD}  🔍 YOUR CHALLENGE — Can you find the bug?${RESET}"
  echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════${RESET}"
  echo ""
  echo -e "  1. Observe the symptoms with:  ${BOLD}kubectl get pods${RESET}"
  echo -e "  2. Investigate with:           ${BOLD}kubectl describe pod <name>${RESET}"
  echo -e "  3. Check logs with:            ${BOLD}kubectl logs <name> [--previous]${RESET}"
  echo -e "  4. Check events with:          ${BOLD}kubectl get events --sort-by=.lastTimestamp${RESET}"
  echo ""
  echo -e "  ${YELLOW}Hint: Read the comments inside ${manifest##*/} for the answer.${RESET}"
  echo ""

  echo -e "${BOLD}🧹 Cleanup when done:${RESET}"
  echo -e "  kubectl delete -f ${manifest##*/}"
  echo ""
}

teardown_episode() {
  local ep_num
  ep_num=$(printf "%02d" "$1")
  local manifest
  manifest=$(find "$SCRIPT_DIR" -name "episode-${ep_num}-*.yaml" | head -1)

  if [ -z "$manifest" ]; then
    echo -e "${RED}Episode ${ep_num} not found.${RESET}"
    exit 1
  fi

  echo -e "${RED}🧹 Tearing down episode ${ep_num}...${RESET}"
  kubectl delete -f "$manifest" --ignore-not-found=true
  echo -e "${GREEN}Done.${RESET}"
}

print_banner

case "${1:-}" in
  ""|-l|--list)
    list_episodes
    ;;
  --teardown|--cleanup|-d)
    teardown_episode "${2:-0}"
    ;;
  [0-9]*)
    apply_episode "$1"
    ;;
  *)
    echo "Usage: $0 [episode-number|--list|--teardown <episode-number>]"
    exit 1
    ;;
esac
