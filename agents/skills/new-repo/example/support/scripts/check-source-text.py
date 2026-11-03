#!/usr/bin/env python3
"""
Pre-commit guard: reject non-ASCII punctuation that has an obvious ASCII swap.

It is a blacklist, not a full non-ASCII ban: names and test data legitimately
need other code points. Extend `_PATTERNS` with project-specific citations
(e.g. `\\bADR[ -]?\\d+`, ticket ids) that belong in docs, not source.

A file opts out entirely with a comment line (a `#`, `//` or `--` leader)
containing `check-source-text: off`.

Rejections go to stdout as `path:lineno: <the offending line>`.
"""

import argparse
import re
import sys

_OFF = re.compile(r'(?:#|//|--)[ \t]*check-source-text:[ \t]*off')

# The non-ASCII chars are spelled with `chr` so this file stays ASCII.
_PATTERNS = [
	re.compile(chr(0x00A7)),  # paragraph sign
	re.compile(chr(0x2014)),  # em-dash (use two hyphens)
	re.compile(chr(0x2500)),  # box-drawing horizontal (use -)
	re.compile(chr(0x2192)),  # rightwards arrow (use ->)
	re.compile(chr(0x2026)),  # ellipsis (use ...)
]


def _violations(path: str):
	try:
		with open(path, encoding='utf-8') as f:
			text = f.read()
	except (OSError, UnicodeDecodeError) as e:
		yield 0, f'could not read: {e}'
		return
	if _OFF.search(text):
		return
	for lineno, line in enumerate(text.splitlines(), 1):
		if any(pat.search(line) for pat in _PATTERNS):
			yield lineno, line.strip()


def main(argv: list[str]) -> int:
	parser = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
	parser.add_argument('files', nargs='*', help='files to check')
	args = parser.parse_args(argv)

	found = False
	for path in args.files:
		for lineno, content in _violations(path):
			found = True
			print(f'{path}:{lineno}: {content}')
	if found:
		print(
			'\nSource text must avoid non-ASCII punctuation; '
			'add `check-source-text: off` in a comment to skip a file.',
			file=sys.stderr,
		)
		return 1
	return 0


if __name__ == '__main__':
	sys.exit(main(sys.argv[1:]))
