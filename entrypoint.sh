#! /bin/bash

trap "exit 0" SIGINT SIGTERM

HOME=$(cd $(dirname $0);pwd)
IP_FILE="$HOME/data/ip"
IP_CHECK_URL=${IP_CHECK_URL:-"http://checkip.amazonaws.com"}
CHECK_INTERVAL=${CHECK_INTERVAL:-60}
NOTIFY_INTERVAL=${NOTIFY_INTERVAL:-3600}

function webhook() {
    if [ -z "$WEBHOOK" ]; then
        echo "WEBHOOK is not set. Skipping webhook notification."
    else
        curl -s -H "Accept: application/json" -H "Content-type: application/json" -X POST -d "{\"content\":\"[$(date +%H:%M:%S)] ${1}\"}" "$WEBHOOK"
    fi
}

function mydns() {
    curl --max-time 10 -sSu ${MYDNS_USERNAME}:${MYDNS_PASSWORD} https://ipv4.mydns.jp/login.html
}

if [ -f "$IP_FILE" ]; then
    SAVED_IP=$(cat $IP_FILE)
    webhook "mydns updater has started. IP=$SAVED_IP, URL=$IP_CHECK_URL"
else
    webhook "mydns updater has started. IP=NO_FILE, URL=$IP_CHECK_URL"
fi

# 最後に通知した時刻を記録
LAST_NOTIFY_TIME=$(date +%s)

while true
do
    sleep $CHECK_INTERVAL & wait $!

    # IPアドレスを取得
    CURRENT_IP=$(curl -sS "$IP_CHECK_URL")

    # 保存IPアドレスがあるとき
    if [ -f "$IP_FILE" ]; then
        # 読み出し
        SAVED_IP=$(cat $IP_FILE)
        echo "保存されている IP = $SAVED_IP"

        # 現在のIPがxxx.xxx.xxx.xxxに当てはまるか正規表現で確認
        if [[ "$CURRENT_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            # 保存されているものと一致しているか
            if [[ "$SAVED_IP" != "$CURRENT_IP" ]];then
                echo "$CURRENT_IP" > $IP_FILE
                mydns
                webhook "IP address changed from ${SAVED_IP} to ${CURRENT_IP}. MyDNS update completed."
            fi
        else
            webhook "IP=${CURRENT_IP}"
        fi
    else
        echo "$CURRENT_IP" > $IP_FILE
    fi

    # 通知間隔が経過したかチェック
    CURRENT_TIME=$(date +%s)
    TIME_DIFF=$((CURRENT_TIME - LAST_NOTIFY_TIME))
    
    if [ $TIME_DIFF -ge $NOTIFY_INTERVAL ]; then
        webhook "Current IP=${CURRENT_IP}"
        LAST_NOTIFY_TIME=$CURRENT_TIME
    fi
done