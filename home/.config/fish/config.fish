alias clear="printf '\033[2J\033[3J\033[1;1H'"
if test -f ~/.bashrc
	bass source ~/.bashrc
end

if status is-interactive
	if test "$TERM" = xterm-kitty; and command -v kitty > /dev/null
		alias ssh="kitty +kitten ssh"
	end
	if command -v zoxide > /dev/null
		zoxide init fish | source
	end
	if command -v carapace > /dev/null
		carapace _carapace | source
	end
end

export GPG_TTY=(tty)
