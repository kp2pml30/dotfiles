if status is-interactive
	if test -f ~/.ghcup/env
		bass source ~/.ghcup/env
	end
	if test -x ~/.rbenv/bin/rbenv
		~/.rbenv/bin/rbenv init - fish | source
	end
	if command -v zoxide > /dev/null
		zoxide init fish | source
	end
end
