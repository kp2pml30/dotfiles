alias clear="printf '\033[2J\033[3J\033[1;1H'"
if test -f ~/.bashrc
	bass source ~/.bashrc
end

if status is-interactive
	if command -v zoxide > /dev/null
		zoxide init fish | source
	end
end

export GPG_TTY=(tty)
