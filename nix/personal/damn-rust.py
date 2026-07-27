import argparse
import os
import shutil
import subprocess
import sys

import argcomplete

ROOT = os.environ['DAMN_RUST_ROOT']
IMAGE = os.environ['DAMN_RUST_IMAGE']
FSTRIM = os.environ['DAMN_RUST_FSTRIM']
COMPSIZE = os.environ['DAMN_RUST_COMPSIZE']


def fail(message):
	print(f'damn-rust: {message}', file=sys.stderr)
	raise SystemExit(1)


def require_mount():
	# without this a failed mount would silently fill the root filesystem
	if not os.path.ismount(ROOT):
		fail(f'{ROOT} is not a mount point')


def store_path(path):
	# resolve the parent but keep the last component as written: a path reached
	# *through* one of our own symlinks would otherwise map to a store entry
	# nested inside the store, while resolving the last component would turn an
	# already-linked `target` into its own store path
	full = os.path.abspath(path)
	real = os.path.join(os.path.realpath(os.path.dirname(full)), os.path.basename(full))
	if real == ROOT or real.startswith(ROOT + os.sep):
		fail(f'{real} is already inside {ROOT}')
	if real == os.sep:
		fail('refusing to operate on the filesystem root')
	return os.path.join(ROOT, real.lstrip(os.sep))


def human(size):
	for unit in ('B', 'KiB', 'MiB', 'GiB', 'TiB'):
		if abs(size) < 1024 or unit == 'TiB':
			return f'{size:.1f}{unit}'
		size /= 1024


def allocated():
	return os.stat(IMAGE).st_blocks * 512


def cmd_symlink(args):
	require_mount()
	link = os.path.abspath(args.path)
	store = store_path(link)
	if os.path.islink(link):
		current = os.readlink(link)
		if current == store:
			print(f'{link} -> {store} (unchanged)')
			return
		if not args.force:
			fail(f'{link} already points at {current}; pass --force to repoint it')
		os.unlink(link)
	elif os.path.exists(link):
		if not os.path.isdir(link):
			fail(f'{link} exists and is not a directory')
		# --force is an rm -rf, so keep it away from anything that is not a
		# build directory sitting inside a project
		if os.path.ismount(link) or link == os.path.expanduser('~'):
			fail(f'refusing to replace {link}')
		if os.listdir(link) and not args.force:
			fail(f'{link} exists and is not empty; pass --force to delete it')
		shutil.rmtree(link)
	os.makedirs(store, exist_ok=True)
	os.makedirs(os.path.dirname(link), exist_ok=True)
	os.symlink(store, link)
	print(f'{link} -> {store}')


def cmd_wipe(args):
	require_mount()
	store = store_path(args.path)
	if not os.path.exists(store):
		print(f'nothing under {store}')
		return
	# files only: the directory skeleton stays, so the symlinks pointing into it
	# keep resolving
	removed = 0
	for dirpath, dirnames, filenames in os.walk(store, followlinks=False):
		# a symlink to a directory is listed in dirnames but is still a file to us
		for name in filenames + [
			d for d in dirnames if os.path.islink(os.path.join(dirpath, d))
		]:
			os.remove(os.path.join(dirpath, name))
			removed += 1
	print(f'removed {removed} file(s) under {store}')


def cmd_shrink(args):
	require_mount()
	os.sync()
	before = allocated()
	# loop punches holes in the backing file for every discarded block
	trim = [FSTRIM, '-v', ROOT]
	if os.geteuid() != 0:
		trim = ['sudo', *trim]
	subprocess.run(trim, check=True)
	after = allocated()
	print(
		f'{IMAGE}: {human(before)} -> {human(after)} on disk, freed {human(before - after)}'
	)


def cmd_usage(args):
	require_mount()
	# only compsize knows the pre-compression size; st_blocks is post-compression
	run = [COMPSIZE, ROOT]
	if os.geteuid() != 0:
		run = ['sudo', *run]
	subprocess.run(run, check=True)
	print(f'{IMAGE}: {human(allocated())} allocated of {human(os.stat(IMAGE).st_size)}')


parser = argparse.ArgumentParser(
	prog='damn-rust',
	description='Keep rust build directories on the file-backed btrfs store.',
)
sub = parser.add_subparsers(required=True)

symlink = sub.add_parser('symlink', help='point a build directory at the store')
symlink.add_argument(
	'--path', default='target', help='directory to redirect (default: target)'
).completer = argcomplete.completers.DirectoriesCompleter()
symlink.add_argument(
	'--force', action='store_true', help='replace an existing directory or symlink'
)
symlink.set_defaults(func=cmd_symlink)

wipe = sub.add_parser('wipe', help='delete the files the store holds for a path')
wipe.add_argument(
	'--path', default='.', help='path whose store files to delete (default: .)'
).completer = argcomplete.completers.DirectoriesCompleter()
wipe.set_defaults(func=cmd_wipe)

shrink = sub.add_parser('shrink', help='return freed store blocks to the sparse image')
shrink.set_defaults(func=cmd_shrink)

usage = sub.add_parser('usage', help='report what the store holds and what zstd saved')
usage.set_defaults(func=cmd_usage)

argcomplete.autocomplete(parser)
args = parser.parse_args()
args.func(args)
