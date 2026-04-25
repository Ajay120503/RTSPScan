# 📡 RTSP Scanner — Multi-Mode Port 554 Scanner

> A dynamic Bash script to discover devices with open RTSP ports on your own network,
> with a clean terminal UI, multiple input modes, and direct integration with **RTSPBrute**.

---

## ⚠️ Legal Disclaimer

> **This tool is strictly for authorized security testing only.**
> Only use this on networks and devices **you own or have explicit written permission to test**.
> Unauthorized port scanning is illegal in most countries.
> The author assumes **zero liability** for any misuse.

---

## ✨ Features

- 🎯 **6 scan modes** — auto-detect, CIDR, IP range, single IP, TXT file, multi-range
- 🎛️ **Port selector** — 554, 8554, 5554, or custom
- ⚡ **Speed selector** — Slow / Normal / Fast / Turbo
- 📊 **Live terminal UI** — animated progress bar, found count, host count, elapsed time
- 📋 **Results table** — sorted, deduplicated, numbered
- 💾 **Auto-saves** to `open554.txt`
- 🔁 **Scan again** prompt after each run
- 🔗 **RTSPBrute ready** — prints the exact next command to run

---

## 📋 Requirements

| Tool | Purpose |
|------|---------|
| `bash` | Shell (pre-installed on Ubuntu) |
| `nmap` | Port scanning engine |
| `awk` | Output parsing |
| `grep` | Pattern matching |

> The script auto-installs any missing dependencies via `apt`.

---

## 🚀 Installation

### Option 1 — Clone from GitHub

```bash
git clone https://github.com/yourusername/rtsp-scanner.git
cd rtsp-scanner
chmod +x rtsp_scan.sh
./rtsp_scan.sh
```

### Option 2 — Download directly

```bash
wget https://raw.githubusercontent.com/yourusername/rtsp-scanner/main/rtsp_scan.sh
chmod +x rtsp_scan.sh
./rtsp_scan.sh
```

### Option 3 — Install globally (run from anywhere)

```bash
sudo cp rtsp_scan.sh /usr/local/bin/rtsp-scan
sudo chmod +x /usr/local/bin/rtsp-scan
rtsp-scan
```

---

## 📦 Install nmap (if not already installed)

```bash
sudo apt update && sudo apt install nmap -y
```

---

## 🖥️ Usage

Simply run:

```bash
./rtsp_scan.sh
```

The script guides you through every option interactively — no flags needed.

---

## 🔢 Step-by-Step Walkthrough

### Step 1 — Choose Scan Mode

```
══════════════════════════════════════════════
  SELECT SCAN MODE
══════════════════════════════════════════════

  [1]  Auto-detect     → 192.168.1.0/24  (current network)
  [2]  Manual CIDR     → e.g.  192.168.1.0/24
  [3]  IP Range        → e.g.  10.0.0.1 → 10.0.0.254
  [4]  Single IP       → e.g.  192.168.1.105
  [5]  From TXT File   → Load IPs / CIDRs / ranges from a file
  [6]  Multiple Ranges → Comma-separated ranges at once

  ▶ Choose [1-6]:
```

---

### Step 2 — Choose Ports

```
  [1]  554 only          Standard RTSP
  [2]  554, 8554         Standard + alternate
  [3]  554, 5554, 8554   All common RTSP ports
  [4]  Custom            Enter your own

  ▶ Choose [1-4] (default=1):
```

---

### Step 3 — Choose Speed

```
  [1]  Slow    T2 — Quiet, reliable, low noise
  [2]  Normal  T3 — Balanced
  [3]  Fast    T4 — Aggressive (recommended)
  [4]  Turbo   T5 — Very aggressive

  ▶ Choose [1-4] (default=3):
```

---

### Step 4 — Review & Confirm

```
══════════════════════════════════════════════
  SCAN SUMMARY
══════════════════════════════════════════════
  Mode     :  Auto-Detect
  Target   :  192.168.1.0/24
  Ports    :  554
  Speed    :  -T4 --min-parallelism 50
  Output   :  /home/user/open554.txt
══════════════════════════════════════════════

  Press Enter to start or Ctrl+C to cancel...
```

---

### Step 5 — Live Progress

```
  ⠹  [▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░]  Found: 3     Hosts: 142     21s
```

---

### Step 6 — Results

```
══════════════════════════════════════════════
  RESULTS
══════════════════════════════════════════════
  Hosts with open port(s) :  3
  Ports scanned           :  554
  Total time              :  34s
  Saved to                :  /home/user/open554.txt
══════════════════════════════════════════════

  ┌────┬────────────────────────────────────┐
  │ No.│ IP Address                         │
  ├────┼────────────────────────────────────┤
  │ 1  │ 192.168.1.5                        │
  │ 2  │ 192.168.1.22                       │
  │ 3  │ 192.168.1.87                       │
  └────┴────────────────────────────────────┘

  rtspbrute -t open554.txt -c credentials.txt -r routes.txt
```

---

## 📂 Scan Modes — Detailed

### Mode 1 — Auto-Detect
Detects your active interface and scans your current network automatically.

### Mode 2 — Manual CIDR
```
▶ 192.168.1.0/24
▶ 10.0.0.0/16
```

### Mode 3 — IP Range
Prompts for start IP and end IP on the same subnet.
```
Start IP ▶ 192.168.1.1
End IP   ▶ 192.168.1.254
```

### Mode 4 — Single IP
```
▶ 192.168.1.105
```

### Mode 5 — From TXT File
Your file can mix any format — one entry per line:
```
# plain IPs
192.168.1.1
10.0.0.5

# CIDR blocks
192.168.0.0/24

# nmap-style ranges
192.168.1.1-50
```

Load it:
```bash
▶ ~/Downloads/targets.txt
▶ /home/user/mylist.txt
```

### Mode 6 — Multiple Ranges (comma-separated)
```
▶ 192.168.1.0/24, 10.0.0.0/24, 172.16.5.0/24
```

---

## 📁 Output File

Results are saved to `open554.txt` in your current working directory:

```
192.168.1.5
192.168.1.22
192.168.1.87
```

---

## 🔗 Next Step — RTSPBrute

Feed the results straight into RTSPBrute:

```bash
# Basic
rtspbrute -t open554.txt

# With wordlists
rtspbrute -t open554.txt -c credentials.txt -r routes.txt

# With multiple ports
rtspbrute -t open554.txt -p 554 8554 -c credentials.txt -r routes.txt
```

---

## 🔧 Troubleshooting

| Problem | Fix |
|---------|-----|
| `Permission denied` | `chmod +x rtsp_scan.sh` |
| `nmap: command not found` | `sudo apt install nmap -y` |
| Auto-detect wrong network | Use Mode 2 or 3 manually — check with `ip a` |
| No results found | Try more ports (Mode 2 → option 3) or slower speed (T2) |
| Scan too slow | Use Turbo speed (T5) and narrow the IP range |

---

## 📁 Project Structure

```
rtsp-scanner/
├── rtsp_scan.sh       ← Main scanner script
├── targets.txt        ← (optional) your target list
├── open554.txt        ← Auto-generated output
└── README.md
```

---

## ⬆️ Push to GitHub

```bash
# 1. Initialize
git init
git add rtsp_scan.sh README.md
git commit -m "feat: RTSP multi-mode terminal scanner"

# 2. Create repo at github.com/new — then:
git remote add origin https://github.com/yourusername/rtsp-scanner.git
git branch -M main
git push -u origin main
```

---

## 📜 License

MIT License — free to use, modify, and distribute.

---

## 🙏 Credits

- [nmap](https://nmap.org/) — the scanning engine powering this tool
- [RTSPBrute](https://gitlab.com/woolf/RTSPbrute) — original RTSP brute-force tool by Woolf
- RTSPBrute Python 3.12 port — modernized for Ubuntu 24.04 LTS
