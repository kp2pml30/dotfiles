#!/usr/bin/env bash

set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

HOST=""
PORT=""
GENKEY=false

function show_help {
	echo "wireguard configurator"
	echo "  --host host-name"
	echo "  --port port"
	echo "  [--gen-key]"
}

while [ $# -ne 0 ]
do
	ARG="$1"
	shift
	case "$ARG" in
		--help)
			show_help
			exit 0
			;;
		--host)
			HOST="$1"
			shift
			;;
		--port)
			PORT="$1"
			shift
			;;
		--gen-keys)
			GENKEY=true
			;;
		*)
			echo "unknown argument $ARG"
			show_help
			exit 1
			;;
	esac
done

echo "Parsed:"
echo "  --host $HOST"
echo "  --port $PORTI"

if [ "$HOST" == "" ]
then
	echo "host not set"
	show_help
	exit 1
fi

if [ "$PORT" == "" ]
then
	echo "port not set"
	show_help
	exit 1
fi

if [ ! -f .gitignore ]
then
	echo "INFO creating gitignore"
	touch .gitignore
fi

if ! grep -Pq '^/key$' .gitignore
then
	echo "INFO adding key to .gitignore"
	echo "/key" >> .gitignore
fi

if ! grep -Pq '^/wg0\.conf$' .gitignore
then
	echo "INFO adding wg0.conf to .gitignore"
	echo "/wg0.conf" >> .gitignore
fi

if [ "$GENKEY" == "true" ]
then
	touch key
	chmod 600 key
	wg genkey > key
	wg pubkey < key > key.pub
fi

touch wg0.conf
chmod 600 wg0.conf
KEY="$(cat key)"
erb "private_key=$KEY" port="$PORT" "$SCRIPT_DIR/wg0.conf.erb" > wg0.conf
KEY=""

PUBKEY="$(cat key.pub)"

echo ""
echo "Run following to start wireguard:"
echo "  wg-quick up ./wg0.conf"
echo "You can add peers as follows:"
echo "  wg set wg0 peer <pub key> allowed-ips IP"
echo ""
echo "Client's configuration is"
echo "=================================="
cat <<-EOF
[Interface]
Address = 10.30.30.@@/32
PrivateKey = <Private key>
DNS = 10.30.30.1

[Peer]
PublicKey = $PUBKEY
Endpoint = $HOST:$PORT
AllowedIPs = 10.30.30.0/24
PersistentKeepalive = 25
EOF
echo "=================================="
