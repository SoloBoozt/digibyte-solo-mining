#!/bin/bash
# DigiByte Solo Mining — Quick Status Check
#
# Usage: ./check-status.sh

echo "=== DigiByte Node ==="
echo -n "Block height: "
digibyte-cli getblockcount 2>/dev/null || echo "Node not running"

echo -n "Connections: "
digibyte-cli getconnectioncount 2>/dev/null || echo "N/A"

echo -n "SHA256 difficulty: "
digibyte-cli getmininginfo 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(f\"{d.get('difficulty', 'N/A')}\")
except:
    print('N/A')
" 2>/dev/null || echo "N/A"

echo ""
echo "=== ckpool ==="
systemctl --user status ckpool --no-pager 2>/dev/null | head -5 || echo "ckpool service not found"

echo ""
echo "=== Worker Stats ==="
LOGFILE="${HOME}/ckpool-solo/logs/ckpool.log"
if [ -f "$LOGFILE" ]; then
    grep "hashrate\|workers\|bestshare" "$LOGFILE" | tail -1
    echo ""
    grep "Pool:{" "$LOGFILE" | tail -1
else
    echo "No ckpool log found at $LOGFILE"
fi

echo ""
echo "=== Mining Address Balance ==="
# Try to get balance for any address with received funds
digibyte-cli listreceivedbyaddress 0 true 2>/dev/null | python3 -c "
import sys, json
try:
    addrs = json.load(sys.stdin)
    mining = [a for a in addrs if a.get('label') == 'mining']
    if mining:
        for a in mining:
            print(f\"  {a['address']}: {a['amount']} DGB ({a['txids'].__len__()} txs)\")
    else:
        print('  No mining-labeled address found. Check with: digibyte-cli listreceivedbyaddress')
except:
    print('  Could not query wallet')
" 2>/dev/null || echo "  Could not query wallet"
