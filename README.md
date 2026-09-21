# DigiByte Solo Mining — SHA-256 with Your Own Node

Solo mine DigiByte using the SHA-256d algorithm with your own full node and ckpool. No pool fees, no middleman — when you find a block, you keep 100% of the reward.

## What You Need

| Component | Description |
|-----------|-------------|
| **DigiByte Core** | Full node (v8.26.x) synced to mainnet |
| **ckpool** | Solo mining pool software (runs locally) |
| **SHA-256 ASIC miner** | Bitaxe, Antminer S9/S19, etc. |
| **Linux machine** | Ubuntu/Debian recommended (runs 24/7) |

> **Why SHA-256?** DigiByte has 5 mining algorithms. SHA-256d is one of them, and the same hardware that mines Bitcoin (ASICs) can mine DigiByte. With solo mining, you compete against a much lower difficulty than Bitcoin's network.

## Architecture

```
┌──────────────┐     Stratum      ┌──────────┐      RPC       ┌──────────────────┐
│  ASIC Miner  │ ──────────────── │  ckpool  │ ────────────── │  DigiByte Core   │
│  (Bitaxe)    │    port 3333     │  (solo)  │   port 14022   │  (full node)     │
└──────────────┘                  └──────────┘                └──────────────────┘
                                       │
                                  You find a block
                                       │
                                       ▼
                              Block reward → your address
                              (100% — no pool fee)
```

## Step 1: Install and Sync DigiByte Core

### Download

Get the latest stable release from the official sources:

- **Official website**: https://digibyte.org
- **GitHub releases**: https://github.com/DigiByte-Core/digibyte/releases

```bash
# Example for v9.26.5 on Linux x86_64
wget https://github.com/DigiByte-Core/digibyte/releases/download/v9.26.5/digibyte-9.26.5-x86_64-linux-gnu.tar.gz
tar xzf digibyte-9.26.5-x86_64-linux-gnu.tar.gz
sudo cp digibyte-9.26.5/bin/* /usr/local/bin/
```

> **Always verify downloads.** Check the SHA-256 hashes on the release page and verify GPG signatures when available.

### Configure

Create the data directory and configuration file:

```bash
mkdir -p ~/.digibyte
```

Edit `~/.digibyte/digibyte.conf`:

```ini
# DigiByte Core — Mainnet Configuration for Solo Mining

# Enable RPC server (required for ckpool)
server=1

# RPC credentials (CHANGE THESE — use strong random values)
rpcuser=your_rpc_username
rpcpassword=your_rpc_password_change_me

# RPC binding
# For local-only mining (miner on same machine):
rpcbind=127.0.0.1
rpcallowip=127.0.0.1
# For LAN mining (miner on different machine):
# rpcbind=0.0.0.0
# rpcallowip=192.168.0.0/16

# RPC port (default mainnet: 14022)
rpcport=14022

# Performance tuning
dbcache=1024
maxmempool=300
```

### Start and Sync

```bash
# Start the daemon
digibyted -daemon

# Monitor sync progress (takes several hours on first run)
digibyte-cli getblockchaininfo | grep -E "blocks|headers|verificationprogress"

# Check peer connections
digibyte-cli getconnectioncount
```

Wait until `blocks` equals `headers` and `verificationprogress` is close to `1.0` before proceeding.

### Generate a Mining Address

```bash
# Create a wallet (if you don't have one)
digibyte-cli createwallet "mining"

# Generate a bech32 (SegWit) address for mining rewards
digibyte-cli getnewaddress "mining" "bech32"
```

Save this address — it goes in the ckpool config.

## Step 2: Build ckpool

ckpool is Con Kolivas's open-source mining pool software. We use it in solo mode as a local stratum proxy between your ASIC and your DigiByte node.

### Install Dependencies

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y build-essential autoconf automake libtool pkg-config
```

### Compile

```bash
git clone https://bitbucket.org/ckolivas/ckpool.git
cd ckpool
./autogen.sh
./configure
make -j$(nproc)
```

The binary is at `ckpool/src/ckpool`. No need to install system-wide.

## Step 3: Configure ckpool for DigiByte Solo Mining

Create a directory for your solo mining setup:

```bash
mkdir -p ~/ckpool-solo/logs
```

Create `~/ckpool-solo/ckpool.conf`:

```json
{
    "btcd" : [
        {
            "url" : "localhost:14022",
            "auth" : "your_rpc_username",
            "pass" : "your_rpc_password_change_me",
            "notify" : false
        }
    ],
    "btcaddress" : "dgb1q_YOUR_MINING_ADDRESS_HERE",
    "btcsig" : "solo",
    "update_interval" : 30,
    "serverurl" : [
        "0.0.0.0:3333"
    ],
    "mindiff" : 1,
    "startdiff" : 1000,
    "maxdiff" : 0,
    "nonce2length" : 4,
    "logdir" : "/home/YOUR_USERNAME/ckpool-solo/logs"
}
```

> **Note:** The config uses Bitcoin-style key names (`btcd`, `btcaddress`) because ckpool was originally written for Bitcoin. It works with DigiByte without modification — SHA-256d is the same algorithm.

### Configuration Reference

| Key | Value | Description |
|-----|-------|-------------|
| `url` | `localhost:14022` | Your node's RPC endpoint |
| `auth` / `pass` | | Must match `rpcuser`/`rpcpassword` in `digibyte.conf` |
| `notify` | `false` | Set to `false` for solo mining |
| `btcaddress` | `dgb1q...` | Your mining reward address |
| `btcsig` | `"solo"` | Coinbase signature (appears in blocks you mine) |
| `update_interval` | `30` | Work update interval in seconds |
| `serverurl` | `0.0.0.0:3333` | Stratum port miners connect to |
| `mindiff` | `1` | Minimum share difficulty |
| `startdiff` | `1000` | Starting share difficulty (adjust for your hashrate) |
| `maxdiff` | `0` | Maximum difficulty (0 = unlimited) |
| `nonce2length` | `4` | Nonce2 size (4 is standard) |
| `logdir` | path | Directory for log files |

### Start Difficulty Guidance

| Miner Hashrate | Recommended `startdiff` |
|----------------|------------------------|
| < 1 TH/s | 100–500 |
| 1–5 TH/s | 500–2000 |
| 5–50 TH/s | 2000–10000 |
| 50+ TH/s | 10000+ |

Set it so you get roughly 1 share every 5–10 seconds. Too low wastes CPU on your pool machine; too high gives you less granular stats.

## Step 4: Run ckpool

### Manual Start (Testing)

```bash
~/ckpool/src/ckpool -c ~/ckpool-solo/ckpool.conf
```

You should see output like:

```
Got SHA256 difficulty 800000000.0 from getmininginfo
Stored local workbase with 0 transactions
Using SHA256 network diff 800000000.0 from getmininginfo
```

### Systemd Service (Recommended)

Create `~/.config/systemd/user/ckpool.service`:

```ini
[Unit]
Description=CKPool Solo Mining - DigiByte SHA256
After=network.target

[Service]
Type=simple
ExecStart=/home/YOUR_USERNAME/ckpool/src/ckpool -c /home/YOUR_USERNAME/ckpool-solo/ckpool.conf
Restart=always
RestartSec=5
StandardOutput=append:/home/YOUR_USERNAME/ckpool-solo/logs/ckpool-stdout.log
StandardError=append:/home/YOUR_USERNAME/ckpool-solo/logs/ckpool-stderr.log

[Install]
WantedBy=default.target
```

Enable and start:

```bash
# Enable lingering (keeps service running after logout)
loginctl enable-linger $USER

# Reload, enable, and start
systemctl --user daemon-reload
systemctl --user enable ckpool
systemctl --user start ckpool

# Check status
systemctl --user status ckpool
```

Auto-restarts on crash. Survives logouts and reboots.

## Step 5: Point Your Miner

Configure your ASIC miner's stratum settings:

| Setting | Value |
|---------|-------|
| **Pool URL** | `stratum+tcp://YOUR_MACHINE_IP:3333` |
| **Worker** | `dgb1q_YOUR_MINING_ADDRESS` |
| **Password** | `x` (anything works) |

### Bitaxe Example

In the Bitaxe web interface (AxeOS):

- **Stratum URL**: `YOUR_MACHINE_IP`
- **Stratum Port**: `3333`
- **Stratum User**: `dgb1q_YOUR_MINING_ADDRESS`
- **Stratum Password**: `x`

### Antminer / Generic ASIC

In the miner's web interface under "Miner Configuration":

- **Pool 1**: `stratum+tcp://YOUR_MACHINE_IP:3333`
- **Worker**: `dgb1q_YOUR_MINING_ADDRESS`
- **Password**: `x`

> **Important:** The worker name should be your DGB address. ckpool uses it for accounting but in solo mode the coinbase reward always goes to the `btcaddress` in your config.

## Monitoring

### Check Workers

```bash
# Tail the main log
tail -f ~/ckpool-solo/logs/ckpool.log

# Look for worker stats
grep "hashrate\|workers\|bestshare" ~/ckpool-solo/logs/ckpool.log | tail -5
```

Example output:

```
User dgb1q...:{"hashrate1m":"2.09T","hashrate5m":"1.92T","hashrate1hr":"2.06T",
"hashrate1d":"2.17T","hashrate7d":"2.2T","workers":2,"shares":1500740016,
"bestshare":1406696574,"bestever":3648373326}
```

### Check Pool Status

```bash
grep "Pool:" ~/ckpool-solo/logs/ckpool.log | tail -3
```

### Check Node Health

```bash
# Block count
digibyte-cli getblockcount

# Network info
digibyte-cli getmininginfo

# Peer connections
digibyte-cli getconnectioncount
```

### Did I Find a Block?

```bash
# Check your mining address balance
digibyte-cli getreceivedbyaddress "dgb1q_YOUR_ADDRESS" 0

# List recent transactions
digibyte-cli listtransactions "*" 5
```

You can also search your address on [DigiExplorer](https://digiexplorer.info) or [DGB Explorer](https://dgbexplorer.com).

## Understanding Solo Mining Odds

Solo mining is a lottery. Your chance of finding any given block is:

```
P(block) = your_hashrate / network_hashrate
```

### DigiByte SHA-256d Stats (as of March 2026)

| Metric | Value |
|--------|-------|
| SHA-256 block target | 1 block per 75 seconds |
| Network difficulty | ~800M (varies) |
| Network hashrate | ~25 PH/s (estimated) |

### Expected Time Between Blocks

| Your Hashrate | Expected Time |
|---------------|---------------|
| 1 TH/s | ~300 days |
| 2 TH/s | ~150 days |
| 5 TH/s | ~60 days |
| 10 TH/s | ~30 days |
| 100 TH/s | ~3 days |

> **Important:** These are *statistical averages*. You could find a block in 5 minutes or wait a year. That's the nature of solo mining. Luck is measured as: `actual_time / expected_time × 100%`. Under 100% = lucky. Over 100% = unlucky.

### Block Reward

The current DigiByte block reward is approximately **271 DGB** per block and decreases 1% every month.

## Firewall Notes

| Port | Protocol | Direction | Purpose |
|------|----------|-----------|---------|
| 3333 | TCP | Inbound | Stratum (miners → ckpool) |
| 14022 | TCP | Local only | RPC (ckpool → node) |
| 12024 | TCP | Both | P2P (node ↔ network) |

- Port **3333** must be open if your miner is on a different machine than ckpool
- Port **14022** should be restricted to localhost or your LAN (`rpcallowip`)
- Port **12024** needs to be reachable for your node to maintain peers

```bash
# UFW example (Ubuntu)
sudo ufw allow 12024/tcp comment "DigiByte P2P"
sudo ufw allow from 192.168.0.0/16 to any port 3333 comment "Stratum - LAN only"
```

## Troubleshooting

### ckpool won't start

```
Failed to get block template
```

Your node isn't ready. Check that it's fully synced (`verificationprogress` near 1.0) and that `rpcuser`/`rpcpassword` match between `digibyte.conf` and `ckpool.conf`.

### Miner won't connect

- Verify ckpool is running: `systemctl --user status ckpool`
- Check the stratum port is listening: `ss -tlnp | grep 3333`
- Check firewall allows the connection
- Try `telnet YOUR_IP 3333` from the miner's network

### "Non-SHA256 block" messages

```
Non-SHA256 block (algo 4), miners continue current work
```

This is normal. DigiByte has 5 algorithms taking turns. When a non-SHA256 block is found, ckpool correctly tells your miners to keep working on their current job. You only compete on SHA-256d blocks.

### No shares for a long time

- Check miner is connected (ckpool log shows "workers": N)
- Verify hashrate in ckpool stats
- Make sure `startdiff` isn't set too high for your hashrate

### Log rotation

ckpool logs can grow large. Set up logrotate:

```bash
cat > ~/.config/logrotate-ckpool.conf << 'EOF'
/home/YOUR_USERNAME/ckpool-solo/logs/*.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    copytruncate
}
EOF

# Add to crontab
(crontab -l 2>/dev/null; echo "0 0 * * 0 /usr/sbin/logrotate -s ~/.config/logrotate-ckpool.state ~/.config/logrotate-ckpool.conf") | crontab -
```

## Hardware Recommendations

### Budget Solo (< $100)

- **Bitaxe Ultra** (BM1366) — ~1.2 TH/s, 15W, USB-powered
- Best for: learning, lottery-style mining, supporting the network

### Mid-Range Solo ($200–500)

- **2x Bitaxe Ultra** — ~2.4 TH/s combined
- What we run: 2 Bitaxes at ~2.2 TH/s, found 2 blocks in 3 weeks

### Serious Solo ($500+)

- **Antminer S9** — ~14 TH/s, 1350W (cheap used, loud)
- **Antminer S19** — ~95 TH/s, 3250W (expensive, very loud)

> **Power costs matter.** At $0.10/kWh, an S9 costs ~$100/month in electricity. A Bitaxe costs ~$1/month. Calculate your break-even before buying hardware.

## Credits

- [ckpool](https://bitbucket.org/ckolivas/ckpool) by Con Kolivas — the solo mining pool software
- [DigiByte Core](https://github.com/DigiByte-Core/digibyte) — the full node
- [Bitaxe](https://github.com/skot/bitaxe) — open-source ASIC miner hardware

## License

This guide is released under the MIT License. ckpool is licensed under GPLv3.
