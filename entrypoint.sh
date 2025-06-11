#! /bin/bash

trap "exit 0" SIGINT SIGTERM

HOME=$(cd $(dirname $0);pwd)
URL=${CHECKIP:-"http://checkip.amazonaws.com"}
DOMAIN=${MYDNS_DOMAIN}

function webhook() {
    if [ -z "$WEBHOOK" ]; then
        echo "WEBHOOK is not set. Skipping webhook notification."
    else
        curl -s -H "Accept: application/json" -H "Content-type: application/json" -X POST -d "{\"content\":\"[$(date +%H:%M:%S)] ${1}\"}" "$WEBHOOK"
    fi
}

function mydns() {
    echo "Updating MyDNS..."
    curl --max-time 10 -sSu ${MYDNS_USERNAME}:${MYDNS_PASSWORD} https://ipv4.mydns.jp/login.html
    echo "MyDNS update completed."
}

# ドメインが設定されていない場合はエラー終了
if [ -z "$DOMAIN" ]; then
    echo "Error: MYDNS_DOMAIN environment variable is not set or empty"
    webhook "Error: MYDNS_DOMAIN environment variable is not set or empty. Exiting."
    exit 1
fi

echo "Starting mydns updater..."
echo "Domain: $DOMAIN"
echo "Check IP URL: $URL"
webhook "mydns updater has started. Domain: $DOMAIN"

## ループ処理
COUNTER=1

while true
do
    sleep 15 & wait $!

    echo "Checking IP addresses... (Counter: $COUNTER)"

    # IPアドレスを取得
    CURRENT_IP=$(curl -sS --max-time 10 --connect-timeout 5 "$URL")
    DOMAIN_IP=$(timeout 5 getent hosts "$DOMAIN" | awk '{ print $1 }' | head -n1)
    
    echo "Current IP: $CURRENT_IP"
    echo "Domain IP: $DOMAIN_IP"

    # 現在のIPとドメインIPが両方とも有効なIPアドレスかチェック
    if [[ "$CURRENT_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && [[ "$DOMAIN_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        if [[ "$CURRENT_IP" != "$DOMAIN_IP" ]]; then
            echo "⚠️ IP mismatch detected!"
            webhook "⚠️ IP mismatch detected! Current IP: ${CURRENT_IP}, Domain IP (${DOMAIN}): ${DOMAIN_IP}"
            echo "Updating MyDNS due to mismatch..."
            mydns
        else
            echo "✅ IP addresses match"
        fi
    else
        echo "⚠️ Invalid IP address detected - Current IP: ${CURRENT_IP}, Domain IP: ${DOMAIN_IP}"
        webhook "⚠️ Invalid IP detected - Current IP: ${CURRENT_IP}, Domain IP: ${DOMAIN_IP}"
    fi

    ((COUNTER++))
    
    # 1時間に約一回（240 * 15秒 = 3600秒 = 1時間）
    if [ "$((COUNTER % 240))" -eq 0 ]; then
        echo "Hourly report and maintenance update"
        webhook "Hourly report - Current IP: ${CURRENT_IP}, Domain IP (${DOMAIN}): ${DOMAIN_IP}"
        mydns
    fi
done