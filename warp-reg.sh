#!/usr/bin/env bash
ERROR="\e[1;31m"
WARN="\e[93m"
END="\e[0m"

reg() {
    set -e
    keypair=$(openssl genpkey -algorithm X25519|openssl pkey -text -noout)
    private_key=$(echo "$keypair" | awk '/priv:/{flag=1; next} /pub:/{flag=0} flag' | tr -d '[:space:]' | xxd -r -p | base64)
    public_key=$(echo "$keypair" | awk '/pub:/{flag=1} flag' | tr -d '[:space:]' | xxd -r -p | base64)
    curl -X POST 'https://api.cloudflareclient.com/v0a2158/reg' -sL --tlsv1.3 \
    -H 'CF-Client-Version: a-7.21-0721' -H 'Content-Type: application/json' \
    -d \
   '{
        "key":"'${public_key}'",
        "tos":"'$(date +"%Y-%m-%dT%H:%M:%S.000Z")'"
    }' \
        | python3 -m json.tool | sed "/\"account_type\"/i\         \"private_key\": \"$private_key\","
}

reserved() {
    set -e
    reserved_str=$(echo "$warp_info" | grep 'client_id' | cut -d\" -f4)
    reserved_hex=$(echo "$reserved_str" | base64 -d | xxd -p)
    reserved_dec=$(echo "$reserved_hex" | fold -w2 | while read HEX; do printf '%d ' "0x${HEX}"; done | awk '{print "["$1", "$2", "$3"]"}')
    echo -e "{\n    \"reserved_dec\": $reserved_dec,"
    echo -e "    \"reserved_hex\": \"0x$reserved_hex\","
    echo -e "    \"reserved_str\": \"$reserved_str\"\n}"
}

format() {
    echo "{
    \"endpoint\":{"
    echo "$warp_info" | grep -P "(v4|v6)" | grep -vP "(\"v4\": \"172.16.0.2\"|\"v6\": \"2)" | sed "s/ //g" | sed 's/:"/: "/g' | sed 's/^"/       "/g' | sed 's/:0",$/",/g'
    echo '    },'
    echo "$warp_reserved" | grep -P "reserved" | sed "s/ //g" | sed 's/:"/: "/g' | sed 's/:\[/: \[/g' | sed 's/\([0-9]\+\),\([0-9]\+\),\([0-9]\+\)/\1, \2, \3/' | sed 's/^"/    "/g' | sed 's/"$/",/g'
    echo "$warp_info" | grep -P "(private_key|public_key|\"v4\": \"172.16.0.2\"|\"v6\": \"2)" | sed "s/ //g" | sed 's/:"/: "/g' | sed 's/^"/    "/g'
    echo "}"
}

main() {
    warp_info=$(reg) ; exit_code=$?
    if [[ $exit_code != 0 ]];then
        echo "$warp_info"
        echo -e "${ERROR}ERROR:${END} \"reg\" function returned with $exit_code, exiting."
        exit $exit_code
    fi
    warp_reserved=$(reserved) ; exit_code=$?
    if [[ $exit_code != 0 ]];then
        echo "$warp_reserved"
        echo -e "${ERROR}ERROR:${END} \"reserved\" function returned with $exit_code, exiting."
        exit $exit_code
    fi
    format
}

main
