# inspired by https://github.com/sonowz/vscode-remote-wsl-nixos

# This shell script is run before checking for vscode version updates.
# If a newer version is downloaded, this script won't patch that version,
# resulting in error. Therefore retry is required to patch it.

echo "== '~/.vscode-server/server-env-setup' SCRIPT START =="

# Make sure that basic commands are available
PATH=$PATH:/run/current-system/sw/bin/

# This shell script uses nixpkgs branch from OS version.
# If you want to change this behavior, change environment variable below.
#   e.g. NIXOS_VERSION=unstable
NIXOS_VERSION=$(nixos-version | cut -d "." -f1,2)
echo "NIXOS_VERSION detected as \"$NIXOS_VERSION\""

NIXPKGS_BRANCH=nixos-$NIXOS_VERSION
PKGS_EXPRESSION=nixpkgs/$NIXPKGS_BRANCH#pkgs

# Get directory where this shell script is located
VSCODE_SERVER_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
echo "Got vscode directory : $VSCODE_SERVER_DIR"
echo "If the directory is incorrect, you can hardcode it on the script."

echo "Patching nodejs binaries..."
nix shell $PKGS_EXPRESSION.patchelf $PKGS_EXPRESSION.stdenv.cc -c bash -c "
	for f in \$(find \"$VSCODE_SERVER_DIR/bin/\" -type f -executable)
	do
		if file \"\$f\" | grep -Pi 'elf.*executable' > /dev/null
		then
			patchelf --set-interpreter \"\$(cat \$(nix eval --raw $PKGS_EXPRESSION.stdenv.cc)/nix-support/dynamic-linker)\" --set-rpath \"\$(nix eval --raw $PKGS_EXPRESSION.stdenv.cc.cc.lib)/lib/\" \"\$f\"
		fi
	done
"

echo "== '~/.vscode-server/server-env-setup' SCRIPT END =="

