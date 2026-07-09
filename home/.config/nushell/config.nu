source $"($nu.cache-dir)/carapace.nu"

def --wrapped ssh [...args] {
	if ($env.TERM? == "xterm-kitty") and ((which kitty) | is-not-empty) {
		^kitty +kitten ssh ...$args
	} else {
		^ssh ...$args
	}
}

let carapace_completer = {|spans|
	carapace $spans.0 nushell ...$spans | from json
}

$env.config.completions = {
	algorithm: "fuzzy"
	external: {
		enable: true
		max_results: 100
		completer: $carapace_completer
	}
}
