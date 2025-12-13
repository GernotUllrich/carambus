## Capturing Scoreboard Client Console Output

When the scoreboard kiosk runs on a Raspberry Pi, getting JavaScript console output onto your development machine is tricky because Chromium runs headless in kiosk mode. This guide summarizes three practical approaches that were discussed previously, with detailed steps for the one that proved most successful (Option 3).

### Prerequisites
- Raspberry Pi reachable via SSH (usually `pi@<table-ip>`).
- Scoreboard already deployed (e.g., via `bin/setup-table-raspi.sh` and `deploy-scenario.sh`).
- Local workstation with macOS/Linux for the examples below.

---

## Option 1 – SSH tail of Chromium log file
Best for quick, low-effort snapshots when you only need recent console lines.

1. On the Pi, the kiosk service writes Chromium stdout/stderr to `/tmp/chromium-kiosk.log` (see `bin/autostart-scoreboard.sh`).
2. Stream it remotely:
   ```bash
   ssh pi@192.168.178.81 "sudo journalctl -fu scoreboard-kiosk & tail -F /tmp/chromium-kiosk.log"
   ```
3. Pros: simple; no browser reconfiguration.  
   Cons: only captures what Chromium emits to stdout/stderr; no interactive DevTools features.

---

## Option 2 – Dedicated console-forwarding service
For automated log collection that survives reboots.

1. Create a helper script (e.g., `/usr/local/bin/chromium-console-forwarder.sh`) that tails the log and pushes it through `ssh -R` or `nc`.
2. Run the script as a `systemd` service that depends on `scoreboard-kiosk`.
3. Pros: continuous log shipping to a central host.  
   Cons: requires extra infrastructure; still no DevTools inspection.

---

## Option 3 – Remote Chrome DevTools via port forwarding *(recommended)*
This provides a live browser console, network panel, and DOM inspector from your desktop against the Pi’s Chromium instance. These are the exact steps that worked well during testing.

### Step 1: Launch Chromium with remote debugging enabled
Recent versions of `bin/autostart-scoreboard.sh` already include the flag:
```bash
--remote-debugging-port=9222
```
If your Pi still uses an older script, edit `/usr/local/bin/autostart-scoreboard.sh` (or restart the kiosk manually) to include:
```bash
/usr/bin/chromium-browser \
  ... \
  --remote-debugging-port=9222 \
  ...
```
Restart the kiosk service to apply changes:
```bash
ssh pi@192.168.178.81 "sudo systemctl restart scoreboard-kiosk"
```

### Step 2: Create an SSH tunnel from your desktop
Forward the Pi’s debugging port to your localhost:
```bash
ssh -N -L 9222:localhost:9222 pi@192.168.178.81
```
- `-N` keeps the tunnel open without starting a shell.
- Leave this terminal window running.

### Step 3: Connect with Chrome DevTools on your desktop
1. Open Chrome (or Chromium) on the desktop.
2. Navigate to `chrome://inspect/#devices`.
3. Click “Configure…” under **Discover network targets** and ensure `localhost:9222` is listed (it will be discovered automatically after the first visit).
4. You should now see the Pi’s Chromium instance under **Remote Target**. Click **inspect**.

### Step 4: Use DevTools normally
- The DevTools window behaves exactly like one attached to a local tab: Console, Network, Performance, Application, etc.
- Console messages stream live; you can interact with the DOM, evaluate JS, and observe WebSocket frames for the scoreboard.

### Troubleshooting
| Symptom | Fix |
|---------|-----|
| `ERR_CONNECTION_REFUSED` when opening DevTools | Verify the kiosk Chromium process was restarted with `--remote-debugging-port=9222`. |
| Nothing appears under `chrome://inspect` | Confirm the SSH tunnel is still active; try `telnet localhost 9222` to ensure the port is forwarded. |
| Multiple Chromium tabs shown | The kiosk sometimes spawns more than one window; pick the one matching the scoreboard URL. |

### Why Option 3 is preferred
- Zero changes to the scoreboard application.
- Full fidelity debugging (console, network, timeline, etc.).
- Minimal overhead on the Pi (debug port only adds a lightweight WebSocket listener).
- Works across any network path as long as SSH is available.

---

## Summary
| Option | When to use | Notes |
|--------|-------------|-------|
| 1. SSH tail | Quick textual logs | No interactivity; depends on Chromium writing to stdout/stderr. |
| 2. Forwarding service | Continuous centralized logging | Requires additional scripting and infrastructure. |
| 3. Remote DevTools (recommended) | Interactive debugging, live console | Needs remote-debugging flag + SSH tunnel; delivers full DevTools feature set. |

With these approaches—especially Option 3—you can review the Raspberry Pi client’s console output directly from your desktop without physically touching the scoreboard hardware.


