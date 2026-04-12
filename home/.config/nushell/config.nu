source $"($nu.cache-dir)/carapace.nu"

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
