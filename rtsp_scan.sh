#!/bin/bash
# ─────────────────────────────────────────────
#  RTSP Port 554 Scanner — Multi-Mode
#  For authorized use on your own network only
# ─────────────────────────────────────────────

RED='\033[0;31m';    BRED='\033[1;31m'
GREEN='\033[0;32m';  BGREEN='\033[1;32m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BCYAN='\033[1;36m';  WHITE='\033[1;37m'
DIM='\033[2m';       RESET='\033[0m'
CLEAR_LINE='\033[2K\r'

OUTPUT="open554.txt"
TEMP_RAW=$(mktemp)
TEMP_TARGETS=$(mktemp)
SCAN_START=$(date +%s)
SCAN_MODE=""
TARGET_DISPLAY=""
PORTS="554"
SPEED="-T4 --min-parallelism 50"

# ── UI Helpers ────────────────────────────────
line()  { printf "${DIM}%s${RESET}\n" "─────────────────────────────────────────────"; }
bline() { printf "${CYAN}%s${RESET}\n" "═════════════════════════════════════════════"; }
ok()    { printf "  ${BGREEN}[✓]${RESET} %s\n" "$1"; }
warn()  { printf "  ${YELLOW}[!]${RESET} %s\n" "$1"; }
die()   { printf "\n  ${BRED}[✗] %s${RESET}\n\n" "$1"; cleanup; exit 1; }

cleanup() { rm -f "$TEMP_RAW" "$TEMP_TARGETS"; }
trap 'printf "\n\n  ${YELLOW}[!] Interrupted.${RESET}\n\n"; cleanup; exit 1' INT TERM

banner() {
  clear
  bline
  printf "  ${BCYAN}██████╗ ████████╗███████╗██████╗     ███████╗ ██████╗ █████╗ ███╗${RESET}\n"
  printf "  ${BCYAN}██╔══██╗╚══██╔══╝██╔════╝██╔══██╗   ██╔════╝██╔════╝██╔══██╗████╗${RESET}\n"
  printf "  ${BCYAN}██████╔╝   ██║   ███████╗██████╔╝   ███████╗██║     ███████║██╔██╗${RESET}\n"
  printf "  ${CYAN}██╔══██╗   ██║   ╚════██║██╔═══╝    ╚════██║██║     ██╔══██║██║╚██╗${RESET}\n"
  printf "  ${CYAN}██║  ██║   ██║   ███████║██║        ███████║╚██████╗██║  ██║██║ ╚██╗${RESET}\n"
  printf "  ${DIM}╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝        ╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝${RESET}\n"
  printf "  ${DIM}                                              Multi-Mode Port Scanner${RESET}\n"
  bline
  printf "  ${DIM}⚠  Only scan networks you own or have explicit permission to test${RESET}\n"
  bline
  echo
}

check_deps() {
  local missing=()
  for cmd in nmap awk grep; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    warn "Missing tools: ${missing[*]} — installing..."
    sudo apt install -y "${missing[@]}" -qq &>/dev/null
    ok "Dependencies installed"
  else
    ok "Dependencies OK"
  fi
}

detect_network() {
  local iface cidr
  iface=$(ip route | grep default | awk '{print $5}' | head -1)
  cidr=$(ip -o -f inet addr show "$iface" 2>/dev/null | awk '{print $4}' | head -1)
  echo "$cidr"
}

# ── Mode Menu ─────────────────────────────────
show_menu() {
  local auto
  auto=$(detect_network)

  bline
  printf "  ${WHITE}SELECT SCAN MODE${RESET}\n"
  bline
  printf "\n"
  printf "  ${BCYAN}[1]${RESET}  ${WHITE}Auto-detect     ${RESET}${DIM}Scan current network  →  ${CYAN}%s${RESET}\n" "${auto:-not detected}"
  printf "  ${BCYAN}[2]${RESET}  ${WHITE}Manual CIDR     ${RESET}${DIM}e.g.  192.168.1.0/24${RESET}\n"
  printf "  ${BCYAN}[3]${RESET}  ${WHITE}IP Range        ${RESET}${DIM}e.g.  10.0.0.1 → 10.0.0.254${RESET}\n"
  printf "  ${BCYAN}[4]${RESET}  ${WHITE}Single IP       ${RESET}${DIM}e.g.  192.168.1.105${RESET}\n"
  printf "  ${BCYAN}[5]${RESET}  ${WHITE}From TXT File   ${RESET}${DIM}Load IPs / CIDRs / ranges from file${RESET}\n"
  printf "  ${BCYAN}[6]${RESET}  ${WHITE}Multiple Ranges ${RESET}${DIM}Comma-separated  e.g.  192.168.1.0/24, 10.0.0.0/24${RESET}\n"
  printf "\n"
  bline
  printf "  ${CYAN}▶ Choose [1-6]: ${RESET}"
  read -r choice
  echo

  case "$choice" in
    1) mode_auto "$auto" ;;
    2) mode_cidr ;;
    3) mode_range ;;
    4) mode_single ;;
    5) mode_file ;;
    6) mode_multi ;;
    *) warn "Invalid option — try again"; echo; show_menu ;;
  esac
}

# ── Modes ─────────────────────────────────────
mode_auto() {
  [[ -z "$1" ]] && die "Could not auto-detect network. Try Mode 2 or 3."
  SCAN_MODE="Auto-Detect"
  TARGET_DISPLAY="$1"
  echo "$1" > "$TEMP_TARGETS"
  ok "Network detected: $1"
}

mode_cidr() {
  printf "  ${DIM}Enter CIDR range (e.g. 192.168.1.0/24):${RESET}\n"
  printf "  ${CYAN}▶ ${RESET}"
  read -r cidr
  [[ -z "$cidr" ]] && die "No input provided"
  SCAN_MODE="CIDR"
  TARGET_DISPLAY="$cidr"
  echo "$cidr" > "$TEMP_TARGETS"
  ok "Target set: $cidr"
}

mode_range() {
  printf "  ${DIM}Enter start IP:${RESET}\n"
  printf "  ${CYAN}▶ ${RESET}"
  read -r start_ip
  printf "  ${DIM}Enter end IP:${RESET}\n"
  printf "  ${CYAN}▶ ${RESET}"
  read -r end_ip
  [[ -z "$start_ip" || -z "$end_ip" ]] && die "Both IPs required"

  # Build nmap range syntax: 192.168.1.1-50
  local base="${start_ip%.*}"
  local s_oct="${start_ip##*.}"
  local e_oct="${end_ip##*.}"
  local nmap_range="${base}.${s_oct}-${e_oct}"

  SCAN_MODE="IP Range"
  TARGET_DISPLAY="$start_ip → $end_ip"
  echo "$nmap_range" > "$TEMP_TARGETS"
  ok "Range set: $start_ip → $end_ip"
}

mode_single() {
  printf "  ${DIM}Enter IP address:${RESET}\n"
  printf "  ${CYAN}▶ ${RESET}"
  read -r ip
  [[ -z "$ip" ]] && die "No IP provided"
  SCAN_MODE="Single IP"
  TARGET_DISPLAY="$ip"
  echo "$ip" > "$TEMP_TARGETS"
  ok "Target set: $ip"
}

mode_file() {
  printf "  ${DIM}Enter path to .txt file:${RESET}\n"
  printf "  ${CYAN}▶ ${RESET}"
  read -r fpath
  # Expand tilde
  fpath="${fpath/#\~/$HOME}"
  [[ ! -f "$fpath" ]] && die "File not found: $fpath"

  > "$TEMP_TARGETS"
  # Extract plain IPs and CIDRs
  grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?' "$fpath" >> "$TEMP_TARGETS"
  # Extract nmap-style ranges like 192.168.1.1-50
  grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}-[0-9]{1,3}' "$fpath"    >> "$TEMP_TARGETS"

  # Deduplicate
  sort -u "$TEMP_TARGETS" -o "$TEMP_TARGETS"

  local count
  count=$(grep -c . "$TEMP_TARGETS" 2>/dev/null || echo 0)
  [[ "$count" -eq 0 ]] && die "No valid IPs or CIDRs found in: $fpath"

  SCAN_MODE="From File"
  TARGET_DISPLAY="$fpath  ($count entries)"
  ok "Loaded $count targets from file"

  # Preview first 5
  echo
  printf "  ${DIM}Preview (first 5):${RESET}\n"
  head -5 "$TEMP_TARGETS" | while IFS= read -r t; do
    printf "    ${DIM}→${RESET} ${CYAN}%s${RESET}\n" "$t"
  done
  echo
}

mode_multi() {
  printf "  ${DIM}Enter ranges/IPs separated by commas:${RESET}\n"
  printf "  ${DIM}e.g. 192.168.1.0/24, 10.0.0.0/24, 172.16.0.5${RESET}\n"
  printf "  ${CYAN}▶ ${RESET}"
  read -r raw
  [[ -z "$raw" ]] && die "No input provided"

  > "$TEMP_TARGETS"
  IFS=',' read -ra parts <<< "$raw"
  for part in "${parts[@]}"; do
    trimmed=$(echo "$part" | xargs)
    [[ -n "$trimmed" ]] && echo "$trimmed" >> "$TEMP_TARGETS"
  done

  local count
  count=$(grep -c . "$TEMP_TARGETS" 2>/dev/null || echo 0)
  SCAN_MODE="Multi-Range"
  TARGET_DISPLAY="$count ranges/IPs"
  ok "Queued $count targets"

  printf "\n  ${DIM}Targets:${RESET}\n"
  while IFS= read -r t; do
    printf "    ${DIM}→${RESET} ${CYAN}%s${RESET}\n" "$t"
  done < "$TEMP_TARGETS"
  echo
}

# ── Port selector ─────────────────────────────
select_ports() {
  echo
  bline
  printf "  ${WHITE}PORT SELECTION${RESET}\n"
  bline
  printf "\n"
  printf "  ${BCYAN}[1]${RESET}  ${WHITE}554 only          ${DIM}Standard RTSP${RESET}\n"
  printf "  ${BCYAN}[2]${RESET}  ${WHITE}554, 8554         ${DIM}Standard + alternate${RESET}\n"
  printf "  ${BCYAN}[3]${RESET}  ${WHITE}554, 5554, 8554   ${DIM}All common RTSP ports${RESET}\n"
  printf "  ${BCYAN}[4]${RESET}  ${WHITE}Custom            ${DIM}Enter your own${RESET}\n"
  printf "\n"
  printf "  ${CYAN}▶ Choose [1-4] (default=1): ${RESET}"
  read -r pchoice
  echo

  case "$pchoice" in
    2) PORTS="554,8554" ;;
    3) PORTS="554,5554,8554" ;;
    4)
       printf "  ${DIM}Enter ports (comma-separated, e.g. 554,8080):${RESET}\n"
       printf "  ${CYAN}▶ ${RESET}"
       read -r PORTS
       ;;
    *) PORTS="554" ;;
  esac
  ok "Ports: $PORTS"
}

# ── Speed selector ────────────────────────────
select_speed() {
  echo
  bline
  printf "  ${WHITE}SCAN SPEED${RESET}\n"
  bline
  printf "\n"
  printf "  ${BCYAN}[1]${RESET}  ${GREEN}Slow    ${RESET}${DIM}T2 — Quiet, reliable, low detection${RESET}\n"
  printf "  ${BCYAN}[2]${RESET}  ${YELLOW}Normal  ${RESET}${DIM}T3 — Balanced${RESET}\n"
  printf "  ${BCYAN}[3]${RESET}  ${RED}Fast    ${RESET}${DIM}T4 — Aggressive (recommended)${RESET}\n"
  printf "  ${BCYAN}[4]${RESET}  ${BRED}Turbo   ${RESET}${DIM}T5 — Very aggressive, may miss hosts${RESET}\n"
  printf "\n"
  printf "  ${CYAN}▶ Choose [1-4] (default=3): ${RESET}"
  read -r schoice
  echo

  case "$schoice" in
    1) SPEED="-T2" ;;
    2) SPEED="-T3" ;;
    4) SPEED="-T5 --min-parallelism 100 --max-retries 1" ;;
    *) SPEED="-T4 --min-parallelism 50" ;;
  esac
  ok "Speed: $SPEED"
}

# ── Summary ───────────────────────────────────
show_summary() {
  echo
  bline
  printf "  ${WHITE}SCAN SUMMARY${RESET}\n"
  bline
  printf "  ${WHITE}Mode     :${RESET}  ${CYAN}%s${RESET}\n"  "$SCAN_MODE"
  printf "  ${WHITE}Target   :${RESET}  ${CYAN}%s${RESET}\n"  "$TARGET_DISPLAY"
  printf "  ${WHITE}Ports    :${RESET}  ${CYAN}%s${RESET}\n"  "$PORTS"
  printf "  ${WHITE}Speed    :${RESET}  ${CYAN}%s${RESET}\n"  "$SPEED"
  printf "  ${WHITE}Output   :${RESET}  ${CYAN}%s${RESET}\n"  "$(pwd)/$OUTPUT"
  bline
  printf "\n  ${YELLOW}Press Enter to start or Ctrl+C to cancel...${RESET} "
  read -r
}

# ── Run Scan ──────────────────────────────────
run_scan() {
  SCAN_START=$(date +%s)
  > "$TEMP_RAW"
  > "$OUTPUT"

  mapfile -t targets_arr < "$TEMP_TARGETS"

  nmap -p "$PORTS" --open $SPEED -oG "$TEMP_RAW" "${targets_arr[@]}" &>/dev/null &
  local NMAP_PID=$!

  local found=0 scanned=0 elapsed=0
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local fi=0

  echo
  bline
  printf "  ${BGREEN}SCANNING${RESET}  ${DIM}%s${RESET}\n" "$TARGET_DISPLAY"
  bline
  echo

  while kill -0 "$NMAP_PID" 2>/dev/null; do
    found=$(grep -c "open" "$TEMP_RAW" 2>/dev/null); found=${found//[^0-9]/}; found=${found:-0}
    scanned=$(grep -cE "^Host:" "$TEMP_RAW" 2>/dev/null); scanned=${scanned//[^0-9]/}; scanned=${scanned:-0}
    elapsed=$(( $(date +%s) - SCAN_START ))

    local spin="${frames[$fi]}"
    fi=$(( (fi + 1) % ${#frames[@]} ))

    # Animated bar (cycles based on scanned count)
    local bar="" idx mod
    mod=$(( scanned % 30 ))
    for ((idx=0; idx<30; idx++)); do
      if [[ $idx -eq $mod ]];   then bar+="█"
      elif [[ $idx -lt $mod ]]; then bar+="▓"
      else bar+="░"
      fi
    done

    printf "${CLEAR_LINE}  ${CYAN}%s${RESET}  [${CYAN}%s${RESET}]  " "$spin" "$bar"
    printf "${BGREEN}Found: %-4s${RESET}  " "$found"
    printf "${WHITE}Hosts: %-6s${RESET}  " "$scanned"
    printf "${DIM}%ds${RESET}" "$elapsed"

    sleep 0.1
  done

  wait "$NMAP_PID"
  printf "${CLEAR_LINE}"
  echo
  ok "Scan finished in $(( $(date +%s) - SCAN_START ))s"
}

# ── Parse & Display Results ───────────────────
show_results() {
  # Parse open IPs from nmap grepable output
  grep "open" "$TEMP_RAW" | awk '{print $2}' \
    | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | uniq > "$OUTPUT"

  local found elapsed
  found=$(grep -c . "$OUTPUT" 2>/dev/null || echo 0)
  elapsed=$(( $(date +%s) - SCAN_START ))

  echo
  bline
  printf "  ${BGREEN}RESULTS${RESET}\n"
  bline
  printf "  ${WHITE}Hosts with open port(s) :${RESET}  ${BGREEN}%s${RESET}\n"  "$found"
  printf "  ${WHITE}Ports scanned           :${RESET}  ${CYAN}%s${RESET}\n"    "$PORTS"
  printf "  ${WHITE}Total time              :${RESET}  ${DIM}%ds${RESET}\n"    "$elapsed"
  printf "  ${WHITE}Saved to                :${RESET}  ${CYAN}%s${RESET}\n"    "$(pwd)/$OUTPUT"
  bline

  if [[ "$found" -gt 0 ]]; then
    echo
    printf "  ${YELLOW}┌────┬────────────────────────────────────┐${RESET}\n"
    printf "  ${YELLOW}│${RESET} ${WHITE}%-3s${RESET}${YELLOW}│${RESET} ${WHITE}%-36s${RESET}${YELLOW}│${RESET}\n" "No." "IP Address"
    printf "  ${YELLOW}├────┼────────────────────────────────────┤${RESET}\n"
    local i=1
    while IFS= read -r ip; do
      printf "  ${YELLOW}│${RESET} ${DIM}%-3s${RESET}${YELLOW}│${RESET} ${BCYAN}%-36s${RESET}${YELLOW}│${RESET}\n" "$i" "$ip"
      (( i++ ))
    done < "$OUTPUT"
    printf "  ${YELLOW}└────┴────────────────────────────────────┘${RESET}\n"
    echo
    line
    printf "  ${DIM}Run rtspbrute on these results:${RESET}\n"
    printf "  ${BGREEN}rtspbrute -t %s -c credentials.txt -r routes.txt${RESET}\n" "$OUTPUT"
    line
  else
    echo
    warn "No open hosts found on port(s): $PORTS"
    warn "Try a different speed, port, or target range."
  fi
  echo
}

# ── Repeat prompt ─────────────────────────────
ask_repeat() {
  printf "  ${CYAN}Scan again? [y/N]: ${RESET}"
  read -r again
  echo
  if [[ "$again" =~ ^[Yy]$ ]]; then
    main
  else
    printf "  ${DIM}Done. Results saved to${RESET} ${CYAN}%s${RESET}\n\n" "$(pwd)/$OUTPUT"
    cleanup
    exit 0
  fi
}

# ── Entry Point ───────────────────────────────
main() {
  banner
  check_deps
  echo
  show_menu
  select_ports
  select_speed
  show_summary
  run_scan
  show_results
  ask_repeat
}

main
