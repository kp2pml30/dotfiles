import argparse
import json
import os
import resource
import sys
from urllib.parse import quote

SOCKET_TYPES = {'none': 0, 'starttls': 2, 'ssl': 3}
AUTH_METHODS = {'password-cleartext': 3, 'password-encrypted': 4}


def parse_args():
	parser = argparse.ArgumentParser(
		prog='email',
		description='Run Thunderbird with a throwaway profile that only ever lives in RAM.',
	)
	parser.add_argument(
		'--address', default=os.environ['EMAIL_ADDRESS'], help='default: %(default)s'
	)
	parser.add_argument(
		'--name',
		default=os.environ['EMAIL_NAME'],
		help='display name (default: %(default)s)',
	)
	parser.add_argument('--username', help='login name (default: the address)')
	parser.add_argument(
		'--imap-host', default=os.environ['EMAIL_HOST'], help='default: %(default)s'
	)
	parser.add_argument('--imap-port', type=int, default=993, help='default: %(default)s')
	parser.add_argument(
		'--imap-security', choices=SOCKET_TYPES, default='ssl', help='default: %(default)s'
	)
	parser.add_argument(
		'--smtp-host', default=os.environ['EMAIL_HOST'], help='default: %(default)s'
	)
	parser.add_argument('--smtp-port', type=int, default=465, help='default: %(default)s')
	parser.add_argument(
		'--smtp-security', choices=SOCKET_TYPES, default='ssl', help='default: %(default)s'
	)
	parser.add_argument(
		'--auth',
		choices=AUTH_METHODS,
		default='password-cleartext',
		help='default: %(default)s',
	)
	parser.add_argument(
		'--swap',
		action=argparse.BooleanOptionalAction,
		default=os.environ['EMAIL_SWAP'] == 'true',
		help="let Thunderbird's memory and profile reach swap, and allow sleep while running (default: %(default)s)",
	)
	parser.add_argument(
		'--offline-sync',
		action=argparse.BooleanOptionalAction,
		default=False,
		help='download message bodies into the RAM profile; may need a larger --ram-mib (default: off)',
	)
	parser.add_argument(
		'--ram-mib', type=int, default=1024, help='profile size cap (default: %(default)s)'
	)
	parser.add_argument(
		'--in-swapless-scope', action='store_true', help=argparse.SUPPRESS
	)
	parser.add_argument(
		'thunderbird_args', nargs='*', help='passed to Thunderbird, after --'
	)
	return parser.parse_args()


def account_prefs(args):
	username = args.username or args.address
	folders = f'imap://{quote(username, safe="")}@{args.imap_host}'
	return {
		'mail.accountmanager.accounts': 'account1,account2',
		'mail.accountmanager.defaultaccount': 'account1',
		'mail.accountmanager.localfoldersserver': 'server2',
		'mail.account.account1.identities': 'id1',
		'mail.account.account1.server': 'server1',
		'mail.account.account2.server': 'server2',
		'mail.server.server1.type': 'imap',
		'mail.server.server1.name': args.address,
		'mail.server.server1.hostname': args.imap_host,
		'mail.server.server1.port': args.imap_port,
		'mail.server.server1.socketType': SOCKET_TYPES[args.imap_security],
		'mail.server.server1.authMethod': AUTH_METHODS[args.auth],
		'mail.server.server1.userName': username,
		'mail.server.server1.login_at_startup': True,
		'mail.server.server1.offline_download': args.offline_sync,
		'mail.server.server1.autosync_offline_stores': args.offline_sync,
		'mail.server.server2.type': 'none',
		'mail.server.server2.name': 'Local Folders',
		'mail.server.server2.hostname': 'Local Folders',
		'mail.server.server2.userName': 'nobody',
		'mail.identity.id1.valid': True,
		'mail.identity.id1.fullName': args.name,
		'mail.identity.id1.useremail': args.address,
		'mail.identity.id1.smtpServer': 'smtp1',
		# As the account wizard does
		'mail.identity.id1.fcc_folder': f'{folders}/Sent',
		'mail.identity.id1.fcc_folder_picker_mode': '0',
		'mail.identity.id1.draft_folder': f'{folders}/Drafts',
		'mail.identity.id1.drafts_folder_picker_mode': '0',
		'mail.identity.id1.stationery_folder': f'{folders}/Templates',
		'mail.identity.id1.tmpl_folder_picker_mode': '0',
		'mail.smtpservers': 'smtp1',
		'mail.smtp.defaultserver': 'smtp1',
		'mail.smtpserver.smtp1.hostname': args.smtp_host,
		'mail.smtpserver.smtp1.port': args.smtp_port,
		'mail.smtpserver.smtp1.try_ssl': SOCKET_TYPES[args.smtp_security],
		'mail.smtpserver.smtp1.authMethod': AUTH_METHODS[args.auth],
		'mail.smtpserver.smtp1.username': username,
		'browser.cache.disk.enable': False,
		'mailnews.database.global.indexer.enabled': False,
		'mail.shell.checkDefaultClient': False,
		'mail.rights.override': True,
		'mailnews.start_page.enabled': False,
		'datareporting.policy.dataSubmissionPolicyBypassNotification': True,
		'datareporting.healthreport.uploadEnabled': False,
	}


def user_js(prefs):
	return ''.join(
		f'user_pref({json.dumps(k)}, {json.dumps(v)});\n' for k, v in prefs.items()
	)


def cgroup_swap_max():
	with open('/proc/self/cgroup') as f:
		path = f.read().strip().split('::', 1)[1]
	try:
		with open(f'/sys/fs/cgroup{path}/memory.swap.max') as f:
			return f.read().strip()
	except OSError:
		return None


def main():
	args = parse_args()

	if not args.swap and not args.in_swapless_scope:
		# tmpfs refuses `noswap` in a user namespace; a cgroup also covers the heap.
		# Hibernation ignores the cgroup, and only `sleep` can inhibit it.
		cmd = [
			os.environ['EMAIL_SYSTEMD_INHIBIT'],
			'--what=sleep',
			'--who=email',
			'--why=RAM-only mail profile must not reach a hibernation image',
			'--mode=block',
			os.environ['EMAIL_SYSTEMD_RUN'],
			'--user',
			'--scope',
			'--quiet',
			'--collect',
			'--property=MemorySwapMax=0',
			'--',
			sys.argv[0],
			'--in-swapless-scope',
			*sys.argv[1:],
		]
		os.execv(cmd[0], cmd)

	if not args.swap and cgroup_swap_max() != '0':
		sys.exit(
			'email: could not forbid swap for this session; refusing to start (--swap overrides)'
		)

	resource.setrlimit(resource.RLIMIT_CORE, (0, 0))

	# The mounts die with the namespace, so even SIGKILL leaves nothing behind.
	# Thunderbird keeps a profile's cache in the XDG cache, wherever the profile is.
	ram = os.path.expanduser('~/.thunderbird')
	cache_home = os.environ.get('XDG_CACHE_HOME') or os.path.expanduser('~/.cache')
	cache = f'{cache_home}/thunderbird'
	size = str(args.ram_mib * 1024 * 1024)
	profile = f'{ram}/profile'
	tmp = f'{ram}/tmp'

	read_end, write_end = os.pipe()
	os.write(write_end, user_js(account_prefs(args)).encode())
	os.close(write_end)
	os.set_inheritable(read_end, True)

	cmd = [
		os.environ['EMAIL_BWRAP'],
		'--dev-bind', '/', '/',
		'--size', size,
		'--perms', '0700',
		'--tmpfs', ram,
		'--size', size,
		'--perms', '0700',
		'--tmpfs', cache,
		'--perms', '0700',
		'--dir', profile,
		'--perms', '0700',
		'--dir', tmp,
		'--perms', '0600',
		'--file', str(read_end), f'{profile}/user.js',
		'--setenv', 'TMPDIR', tmp,
		'--',
		os.environ['EMAIL_THUNDERBIRD'],
		'--new-instance',
		'--profile', profile,
		*args.thunderbird_args,
	]  # fmt: skip
	os.execv(cmd[0], cmd)


main()
