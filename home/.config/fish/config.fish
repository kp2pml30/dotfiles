alias clear="printf '\033[2J\033[3J\033[1;1H'"
if test -f ~/.bashrc
	bass source ~/.bashrc
end

if status is-interactive
	# fish 4 defaults ctrl-backspace/ctrl-delete to killing a whole token (argument); swap with alt-
	bind ctrl-backspace backward-kill-word
	bind alt-backspace backward-kill-token
	bind ctrl-delete kill-word
	bind alt-delete kill-token

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
