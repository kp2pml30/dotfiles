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
parser.add_argument(
	"--nvidia-shader-cache-size",
	default=str(10 * 1024 * 1024 * 1024),
	metavar="BYTES",
	help="set NVIDIA shader disk cache size; use 0 to leave it unchanged (default: 10 GiB)",
)
parser.add_argument(
	"--runtime-cache",
	type=parse_bool,
	default=False,
	metavar="BOOL",
	help="move DXVK/vkd3d runtime caches to ~/.cache/game-wrapper; accepts true or false (default: false)",
)
parser.add_argument(
	"--gamescope",
	type=parse_bool,
	default=True,
	metavar="BOOL",
	help="run the game under gamescope; accepts true or false (default: true)",
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

if args.nvidia_shader_cache_size != "0":
	os.environ.setdefault("__GL_SHADER_DISK_CACHE", "1")
	os.environ["__GL_SHADER_DISK_CACHE_SIZE"] = args.nvidia_shader_cache_size

if args.runtime_cache:
	cache_id = (
		os.environ.get("SteamAppId")
		or os.environ.get("SteamGameId")
		or os.path.basename(command[0])
	)
	cache_root = os.path.join(os.path.expanduser("~"), ".cache", "game-wrapper", cache_id)
	dxvk_cache = os.path.join(cache_root, "dxvk")
	vkd3d_cache = os.path.join(cache_root, "vkd3d")
	os.makedirs(dxvk_cache, exist_ok=True)
	os.makedirs(vkd3d_cache, exist_ok=True)
	os.environ.setdefault("DXVK_STATE_CACHE_PATH", dxvk_cache)
	os.environ.setdefault("VKD3D_SHADER_CACHE_PATH", vkd3d_cache)

if args.gamescope:
	command = [
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
	]

os.execvp(command[0], command)
