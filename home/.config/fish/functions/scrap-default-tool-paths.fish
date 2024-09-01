function 'scrap-default-tool-paths'
	set -le NP
	for dir in "$HOME/.cargo/bin" "$HOME/.local/bin" "$HOME/.bin" "$HOME/.ghcup/bin" "$HOME/.cabal/bin"
		if test -d "$dir"
			echo "$dir exists"
			set -a NP "$dir"
		end
	end
	echo "found path is $NP"
	set -U KP2PATH "$NP"

	set -l IFS ''
	set -le COMPLETIONS
	if command -v poetry > /dev/null
		set -l out (poetry completions fish)
		set COMPLETIONS "$COMPLETIONS"\n"$out"
	end
	set -U KP2COMPLETIONS "$COMPLETIONS"
end
