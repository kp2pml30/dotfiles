function read_confirm
	while true
		read -l -P "$argv [y/N] " confirm

		switch $confirm
			case Y y
				return 0
			case '' N n
				return 1
		end
	end
end

function fish_greeting
	if status is-interactive && ! test -f /encrypt/.exists
		if test -f /tmp/.skip-encrypt
			echo "Encrypted drive not installed"
			return
		end
		touch /tmp/.skip-encrypt
		if read_confirm "Setup encrypted drive?"
			set home "$HOME"
			printf "su "
			sudo bash -c "losetup /dev/loop0 '$HOME/encrypted.vhdx' && cryptsetup open /dev/loop0 loop0 && mount /dev/mapper/loop0 /encrypt"
			echo "success: $status"
		end
	end
end

if status is-interactive
	if command -v zoxide > /dev/null
		zoxide init fish | source
	end
end
if command -v poetry > /dev/null
	poetry completions fish | source
end
if test -f ~/.ghcup/env
	bass source ~/.ghcup/env
end
if test -x ~/.rbenv/bin/rbenv
	~/.rbenv/bin/rbenv init - fish | source
end
if test -f ~/.opam/opam-init/init.fish
	source /home/r3vdy-2-b10vv/.opam/opam-init/init.fish
end
alias clear="printf '\033[2J\033[3J\033[1;1H'"
export PATH="$PATH:$HOME/.bin:$HOME/.local/bin"
bass source ~/.bashrc
