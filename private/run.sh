#!/usr/bin/env bash
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


if ! command -v python3
then
	echo "no python3"
	exit 1
fi


echo -n Password:
read -s password
echo

PASS="$password" nvim --clean -n \
	-u "$SCRIPT_DIR/script.vim" \
	"$SCRIPT_DIR/secrets.txt"
