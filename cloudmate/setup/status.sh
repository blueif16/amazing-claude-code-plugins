#!/bin/bash
# ~/.cc/status.sh — CloudMate interactive status viewer
#
# Usage:
#   ~/.cc/status.sh              # Interactive mode (overview + drill-down)
#   ~/.cc/status.sh --watch      # Auto-refresh every 3s (for status pane)
#   ~/.cc/status.sh --once       # Print overview and exit
#
# Keybinds (interactive/watch mode):
#   1-9   Drill into plan detail
#   b     Back to overview
#   q     Quit
#   r     Force refresh

set -uo pipefail

# ── Colors ────────────────────────────────────────────
R='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
CYAN='\033[36m'
GRAY='\033[90m'
BG_DARK='\033[48;5;236m'
WHITE='\033[97m'

# ── Find .tasks/ ──────────────────────────────────────
find_tasks_dir() {
  local main_dir
  main_dir=$(git worktree list 2>/dev/null | head -1 | awk '{print $1}')
  if [ -z "$main_dir" ]; then
    main_dir=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  fi
  echo "$main_dir/.tasks"
}

TASKS_DIR=$(find_tasks_dir)

# ── Parse a plan.md file ──────────────────────────────
parse_plan() {
  local file="$1"
  local name level status type
  name=$(head -1 "$file" | sed 's/^# //')
  level=$(grep -m1 '^Level:' "$file" | grep -o 'Level: [0-9]' | grep -o '[0-9]')
  type=$(grep -m1 '^Branch:' "$file" | grep -o 'Type: [a-z]*' | sed 's/Type: //')
  status=$(grep -m1 '^Branch:' "$file" | grep -o 'Status: [a-z_]*' | sed 's/Status: //')

  local total=0 done=0 progress=0 failed=0 cancelled=0
  while IFS= read -r line; do
    total=$((total + 1))
    case "$line" in
      *"done ✅"*) done=$((done + 1)) ;;
      *"in_progress 🔄"*) progress=$((progress + 1)) ;;
      *"failed ❌"*) failed=$((failed + 1)) ;;
      *"cancelled"*) cancelled=$((cancelled + 1)) ;;
    esac
  done < <(grep '^- Status:' "$file")

  echo "$name|$level|$type|$status|$total|$done|$progress|$failed|$cancelled"
}

# ── Progress bar ──────────────────────────────────────
progress_bar() {
  local done=$1 total=$2 width=${3:-20}
  if [ "$total" -eq 0 ]; then echo ""; return; fi
  local filled=$((done * width / total))
  local empty=$((width - filled))
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done
  local pct=$((done * 100 / total))
  echo "${bar} ${pct}%"
}

# ── Task status line (compact) ────────────────────────
task_status_line() {
  local file="$1"
  local line=""
  local task_ids=()

  while IFS= read -r header; do
    task_ids+=($(echo "$header" | grep -o 'T[0-9]*'))
  done < <(grep '^### T' "$file")

  local i=0
  while IFS= read -r st; do
    local id="${task_ids[$i]:-T?}"
    case "$st" in
      *"done ✅"*)         line+="${GREEN}✅${id}${R} " ;;
      *"in_progress 🔄"*)  line+="${YELLOW}🔄${id}${R} " ;;
      *"failed ❌"*)       line+="${RED}❌${id}${R} " ;;
      *)                    line+="${GRAY}⏳${id}${R} " ;;
    esac
    i=$((i + 1))
  done < <(grep '^- Status:' "$file")

  echo -e "$line"
}

# ── Overview screen ───────────────────────────────────
render_overview() {
  clear
  local files=("$TASKS_DIR"/*.md)
  if [ ! -f "${files[0]}" ] 2>/dev/null; then
    echo -e "${DIM}╔══════════════════════════════════════╗${R}"
    echo -e "${DIM}║${R}  ${BOLD}CloudMate${R} — no active plans        ${DIM}║${R}"
    echo -e "${DIM}║${R}  Run ${CYAN}/cl <task>${R} in a CC slot         ${DIM}║${R}"
    echo -e "${DIM}╚══════════════════════════════════════╝${R}"
    return
  fi

  local active_files=()
  for f in "${files[@]}"; do
    [ -f "$f" ] && active_files+=("$f")
  done

  local count=${#active_files[@]}
  echo -e "${DIM}╔══════════════════════════════════════════════╗${R}"
  echo -e "${DIM}║${R}  ${BOLD}CloudMate${R} — ${WHITE}${count} plan(s)${R}                       ${DIM}║${R}"
  echo -e "${DIM}╠══════════════════════════════════════════════╣${R}"

  local idx=1
  for f in "${active_files[@]}"; do
    local parsed name level type status total done_count prog failed cancelled
    parsed=$(parse_plan "$f")
    IFS='|' read -r name level type status total done_count prog failed cancelled <<< "$parsed"

    local level_label="L${level}"
    local bar
    bar=$(progress_bar "$done_count" "$total" 15)

    local status_color="${CYAN}"
    [ "$status" = "complete" ] && status_color="${GREEN}"
    [ "$status" = "failed" ] && status_color="${RED}"

    echo -e "${DIM}║${R}"
    echo -e "${DIM}║${R}  ${BOLD}${CYAN}${idx}${R}${BOLD}) ${name}${R} ${DIM}[${level_label}]${R} ${status_color}${status}${R}"
    echo -e "${DIM}║${R}     ${done_count}/${total} ${bar}"
    echo -e "${DIM}║${R}     $(task_status_line "$f")"

    idx=$((idx + 1))
  done

  echo -e "${DIM}║${R}"
  echo -e "${DIM}║${R}  ${DIM}[1-${count}] detail · [r] refresh · [q] quit${R}"
  echo -e "${DIM}╚══════════════════════════════════════════════╝${R}"
}

# ── Detail screen ─────────────────────────────────────
render_detail() {
  local file="$1"
  clear

  if [ ! -f "$file" ]; then
    echo -e "${RED}Plan file not found${R}"
    return
  fi

  local parsed name level type status total done_count prog failed cancelled
  parsed=$(parse_plan "$file")
  IFS='|' read -r name level type status total done_count prog failed cancelled <<< "$parsed"

  local bar
  bar=$(progress_bar "$done_count" "$total" 20)

  echo -e "${DIM}╔══════════════════════════════════════════════╗${R}"
  echo -e "${DIM}║${R}  ${BOLD}${name}${R} — L${level} ${type}"
  echo -e "${DIM}║${R}  ${done_count}/${total} ${bar}"
  echo -e "${DIM}╠══════════════════════════════════════════════╣${R}"

  # Extract and display the ASCII tree block
  local in_tree=0
  while IFS= read -r line; do
    if [[ "$line" == '```' ]] && [ "$in_tree" -eq 1 ]; then
      in_tree=0
      continue
    fi
    if [ "$in_tree" -eq 1 ]; then
      local colored="$line"
      colored=$(echo "$colored" | sed "s/✅/$(printf "${GREEN}")✅$(printf "${R}")/g")
      colored=$(echo "$colored" | sed "s/🔄/$(printf "${YELLOW}")🔄$(printf "${R}")/g")
      colored=$(echo "$colored" | sed "s/⏳/$(printf "${GRAY}")⏳$(printf "${R}")/g")
      colored=$(echo "$colored" | sed "s/❌/$(printf "${RED}")❌$(printf "${R}")/g")
      echo -e "${DIM}║${R}  $colored"
    fi
    if [[ "$line" == "## Tree" ]]; then
      read -r
      in_tree=1
    fi
  done < "$file"

  echo -e "${DIM}╠══════════════════════════════════════════════╣${R}"

  # Show task details
  while IFS= read -r line; do
    if [[ "$line" =~ ^###\ T ]]; then
      local title=$(echo "$line" | sed 's/^### //')
      echo -e "${DIM}║${R}"
      echo -e "${DIM}║${R}  ${BOLD}${title}${R}"
    elif [[ "$line" =~ ^-\ Status:\ .*done ]]; then
      echo -e "${DIM}║${R}    ${GREEN}${line}${R}"
    elif [[ "$line" =~ ^-\ Status:\ .*in_progress ]]; then
      echo -e "${DIM}║${R}    ${YELLOW}${line}${R}"
    elif [[ "$line" =~ ^-\ Status:\ .*failed ]]; then
      echo -e "${DIM}║${R}    ${RED}${line}${R}"
    elif [[ "$line" =~ ^-\ Status: ]]; then
      echo -e "${DIM}║${R}    ${GRAY}${line}${R}"
    elif [[ "$line" =~ ^-\ Summary: ]]; then
      echo -e "${DIM}║${R}    ${DIM}${line}${R}"
    elif [[ "$line" =~ ^-\ Verify: ]]; then
      echo -e "${DIM}║${R}    ${line}"
    fi
  done < "$file"

  echo -e "${DIM}║${R}"
  echo -e "${DIM}║${R}  ${DIM}[b] back · [r] refresh · [q] quit${R}"
  echo -e "${DIM}╚══════════════════════════════════════════════╝${R}"
}

# ── Main loop ─────────────────────────────────────────
main() {
  local mode="${1:---watch}"
  local view="overview"
  local detail_file=""
  local refresh_interval=3

  if [ "$mode" = "--once" ]; then
    render_overview
    exit 0
  fi

  tput civis 2>/dev/null
  trap 'tput cnorm 2>/dev/null; exit' EXIT INT TERM

  while true; do
    if [ "$view" = "overview" ]; then
      render_overview
    else
      render_detail "$detail_file"
    fi

    local key=""
    read -rsn1 -t "$refresh_interval" key || true

    case "$key" in
      q|Q) break ;;
      r|R) continue ;;
      b|B) view="overview"; detail_file="" ;;
      [1-9])
        local files=("$TASKS_DIR"/*.md)
        local idx=$((key - 1))
        if [ -f "${files[$idx]:-}" ]; then
          detail_file="${files[$idx]}"
          view="detail"
        fi
        ;;
    esac
  done
}

main "$@"
