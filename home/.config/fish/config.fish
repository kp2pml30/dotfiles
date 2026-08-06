alias clear="printf '\033[2J\033[3J\033[1;1H'"
if test -f ~/.bashrc
	bass source ~/.bashrc
end

if status is-interactive
	# fish 4 defaults ctrl- to whole tokens (arguments) and alt- to words; swap them everywhere
	bind ctrl-backspace backward-kill-word
	bind alt-backspace backward-kill-token
	bind ctrl-alt-h backward-kill-token # what alt-backspace sends without the kitty keyboard protocol
	bind ctrl-delete kill-word
	bind alt-delete kill-token
	bind alt-d 'if test "$(commandline; printf .)" = \n.; __fish_echo dirh; else; commandline -f kill-token; end'

	bind ctrl-left prevd-or-backward-word
	bind ctrl-right nextd-or-forward-word
	bind alt-left backward-token
	bind alt-right forward-token
	bind \e\[1\;9D backward-token
	bind \e\[1\;9C forward-token
	bind alt-b backward-token
	bind alt-f forward-token

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
