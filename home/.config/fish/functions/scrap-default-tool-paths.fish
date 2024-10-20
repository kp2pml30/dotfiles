function __scrap_select
	for cmd in $argv
		if command -v "$cmd" 2> /dev/null > /dev/null
			command -v "$cmd"
			return
		end
	end
end

function 'scrap-default-tool-paths'
	env > /tmp/env-before
	set -Ux PYENV_ROOT $HOME/.pyenv
	set -le NP
	for dir in "$HOME/.cargo/bin" "$HOME/.local/bin" "$HOME/.bin" "$HOME/.ghcup/bin" "$HOME/.cabal/bin" "$HOME/go/bin" "$HOME/.pyenv/bin"
		if test -d "$dir"
			echo "$dir exists"
			if test -n "$NP"
				set NP "$NP:$dir"
			else
				set NP "$dir"
			end
		end
	end
	echo "found path is $NP"
	set -U KP2PATH "$NP"
	set -l OLDP "$PATH"
	set PATH "$NP:$PATH"

	set -le COMPLETIONS
	if command -v poetry > /dev/null
		IFS='' set -l out (poetry completions fish)
		set COMPLETIONS "$COMPLETIONS"\n"$out"
	end
	IFS='' set -U KP2COMPLETIONS "$COMPLETIONS"
	set -Ux EDITOR (__scrap_select nvim vim vi)
	set -Ux PAGER (__scrap_select less more)
	set -Ux GIT_EDITOR "$EDITOR"

	set PATH "$OLDP"
	env > /tmp/env-after
	diff /tmp/env-before /tmp/env-after
	rm /tmp/env-after /tmp/env-before
end
