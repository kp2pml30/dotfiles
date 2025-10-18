#!/bin/sh
set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if ! command -v nvim
then
	echo "no nvim"
	exit 1
fi

if ! command -v base64
then
	echo "no base64"
	exit 1
fi

if ! command -v openssl
then
	echo "no openssl"
	exit 1
fi

env $(cat /var/lib/secrets/.env | xargs) nvim --clean -n \
	-u "$SCRIPT_DIR/modify-secrets.vim" \
	"$SCRIPT_DIR/secrets.yaml"
