import argparse
import os


def parse_bool(value):
	normalized = value.casefold()
	if normalized in {"1", "true", "yes", "on"}:
		return True
	if normalized in {"0", "false", "no", "off"}:
		return False
	raise argparse.ArgumentTypeError(f"invalid boolean value: {value!r}")


parser = argparse.ArgumentParser(
	description="Run a game under gamescope with optional DXVK async flags.",
)
parser.add_argument(
	"--async",
	dest="async_enabled",
	type=parse_bool,
	default=True,
	metavar="BOOL",
	help="enable DXVK async flags; accepts true or false (default: true)",
)
parser.add_argument("command", nargs=argparse.REMAINDER)

args = parser.parse_args()
command = args.command
if command[:1] == ["--"]:
	command = command[1:]

if not command:
	parser.error("missing game command")

if args.async_enabled:
	os.environ["DXVK_ASYNC"] = "1"
	os.environ["DXVK_GPLASYNCCACHE"] = "1"

os.execv(
	os.environ["GAME_WRAPPER_GAMESCOPE"],
	[
		os.environ["GAME_WRAPPER_GAMESCOPE"],
		"-W",
		os.environ["GAME_WRAPPER_WIDTH"],
		"-H",
		os.environ["GAME_WRAPPER_HEIGHT"],
		"-r",
		os.environ["GAME_WRAPPER_REFRESH_RATE"],
		"-f",
		"--",
		*command,
	],
)
