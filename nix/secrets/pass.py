#!/usr/bin/env python3
"""Manage age-encrypted secrets with native age recipients (X-Wing / MLKEM768-X25519).

Layout:
  keys/<id>.pub                  age recipient string (e.g. "age1..." / "age1xwing...")
  data/<path>                    age-encrypted blob
  data/<path>.recipients         one recipient id per line

Identity defaults to /var/lib/secrets/main (override with $PASS_IDENTITY).

Setting up a recipient
----------------------
1. Generate a PQ-hybrid (ML-KEM-768 + X25519) keypair on the recipient's machine:

     sudo install -d -m 0700 /var/lib/secrets
     sudo age-keygen -pq -o /var/lib/secrets/main
     sudo chmod 0600 /var/lib/secrets/main
     sudo age-keygen -y /var/lib/secrets/main | sudo tee /var/lib/secrets/main.pub

   The file contains the private identity. `age-keygen` prints the public
   recipient string as `# public key: age1...` on stderr; that's what other
   machines encrypt to. Recover it later with:

     age-keygen -y /var/lib/secrets/main

2. Commit only the public string into this repo:

     echo 'age1...' > nix/secrets/keys/<id>.pub

   Pick <id> to identify the host or user (e.g. `mini`, `laptop`, `alice`).

3. Create a secret encrypted to one or more recipients:

     ./pass.py edit some/path -r mini -r laptop

   Subsequent edits read the recipient list from
   data/some/path.recipients automatically.

4. Add/remove recipients later (re-encrypts in place):

     ./pass.py reader some/path --add alice --delete laptop
"""

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
KEYS_DIR = ROOT / "keys"
DATA_DIR = ROOT / "data"


def identity_file() -> Path:
    p = os.environ.get("PASS_IDENTITY")
    if p:
        return Path(p)
    return Path("/var/lib/secrets/main")


def key_path(rid: str) -> Path:
    p = KEYS_DIR / f"{rid}.pub"
    if not p.is_file():
        sys.exit(f"unknown recipient {rid!r}: missing {p}")
    return p


def data_path(name: str) -> Path:
    return DATA_DIR / name


def recipients_path(name: str) -> Path:
    return DATA_DIR / f"{name}.recipients"


def read_recipients(name: str) -> list[str]:
    rp = recipients_path(name)
    if not rp.is_file():
        sys.exit(f"missing recipients file {rp}")
    out = []
    for line in rp.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            out.append(line)
    if not out:
        sys.exit(f"recipients file {rp} is empty")
    return out


def write_recipients(name: str, ids: list[str]) -> None:
    rp = recipients_path(name)
    rp.parent.mkdir(parents=True, exist_ok=True)
    rp.write_text("\n".join(ids) + "\n")


def decrypt(name: str) -> bytes:
    dp = data_path(name)
    if not dp.is_file():
        sys.exit(f"missing {dp}")
    ident = identity_file()
    cmd = ["age", "-d", "-i", str(ident), str(dp)]
    if not os.access(ident, os.R_OK):
        print(f"{ident} not readable; prefixing with sudo", file=sys.stderr)
        cmd = ["sudo", "--"] + cmd
    return subprocess.run(cmd, check=True, stdout=subprocess.PIPE).stdout


def encrypt(name: str, plaintext: bytes, ids: list[str]) -> None:
    dp = data_path(name)
    dp.parent.mkdir(parents=True, exist_ok=True)
    args = ["age", "-e", "-a"]
    for rid in ids:
        args += ["-R", str(key_path(rid))]
    args += ["-o", str(dp)]
    subprocess.run(args, check=True, input=plaintext)


def cmd_show(args: argparse.Namespace) -> None:
    sys.stdout.buffer.write(decrypt(args.path))


NVIM_INIT = ROOT / "nvim-pass-init.vim"


def shquote(s: str) -> str:
    return "'" + s.replace("'", "'\\''") + "'"


def cmd_edit(args: argparse.Namespace) -> None:
    name = args.path
    dp = data_path(name)
    rp = recipients_path(name)

    if dp.is_file():
        if args.recipient:
            sys.exit("-r is only allowed when creating a new secret")
        ids = read_recipients(name)
    else:
        if not args.recipient:
            sys.exit(f"{dp} does not exist; pass -r <id> [-r <id>...] to create it")
        ids = list(dict.fromkeys(args.recipient))
        for rid in ids:
            key_path(rid)
        dp.parent.mkdir(parents=True, exist_ok=True)

    ident = identity_file()
    decrypt_cmd = f"age -d -i {shquote(str(ident))}"
    prefix = []
    if not os.access(ident, os.R_OK):
        print(f"{ident} not readable", file=sys.stderr)

    encrypt_cmd = "age -e -a " + " ".join(f"-R {shquote(str(key_path(rid)))}" for rid in ids)

    env = os.environ.copy()
    env["PASS_FILE"] = str(dp)
    env["PASS_DECRYPT_CMD"] = decrypt_cmd
    env["PASS_ENCRYPT_CMD"] = encrypt_cmd
    before = dp.stat().st_mtime_ns if dp.is_file() else 0
    subprocess.run(
        prefix + ["nvim", "--clean", "-n", "-u", str(NVIM_INIT), str(dp)],
        check=True, env=env,
    )
    after = dp.stat().st_mtime_ns if dp.is_file() else 0

    if after == before:
        print("no changes", file=sys.stderr)
        return

    if not rp.is_file() or read_recipients(name) != ids:
        write_recipients(name, ids)


def cmd_create(args: argparse.Namespace) -> None:
    name = args.path
    dp = data_path(name)
    if dp.is_file() and not args.force:
        sys.exit(f"{dp} already exists; pass --force to overwrite or use `edit`")
    if not args.recipient:
        sys.exit("create requires at least one -r <id>")
    ids = list(dict.fromkeys(args.recipient))
    for rid in ids:
        key_path(rid)
    plaintext = sys.stdin.buffer.read()
    if not plaintext:
        sys.exit("refusing to create empty secret from stdin")
    encrypt(name, plaintext, ids)
    write_recipients(name, ids)
    print(f"wrote {dp} (recipients: {', '.join(ids)})", file=sys.stderr)


def cmd_list_recipients(args: argparse.Namespace) -> None:
    for rid in read_recipients(args.path):
        print(rid)


def cmd_reader(args: argparse.Namespace) -> None:
    name = args.path
    if not data_path(name).is_file():
        sys.exit(f"{data_path(name)} does not exist")
    ids = read_recipients(name)
    seen = set(ids)
    for rid in args.add or []:
        key_path(rid)
        if rid not in seen:
            ids.append(rid)
            seen.add(rid)
    for rid in args.delete or []:
        if rid in seen:
            ids.remove(rid)
            seen.discard(rid)
    if not ids:
        sys.exit("refusing to leave secret with no recipients")
    plaintext = decrypt(name)
    encrypt(name, plaintext, ids)
    write_recipients(name, ids)
    print("recipients:", ", ".join(ids))


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = p.add_subparsers(dest="cmd", required=True)

    sp = sub.add_parser("show", help="decrypt to stdout")
    sp.add_argument("path")
    sp.set_defaults(func=cmd_show)

    sp = sub.add_parser("edit", help="edit (creates new file if absent)")
    sp.add_argument("path")
    sp.add_argument("-r", "--recipient", action="append",
                    help="recipient id (from keys/<id>.pub); required when creating; repeatable")
    sp.set_defaults(func=cmd_edit)

    sp = sub.add_parser("create", help="encrypt stdin to <path> with recipients")
    sp.add_argument("path")
    sp.add_argument("-r", "--recipient", action="append",
                    help="recipient id (from keys/<id>.pub); repeatable; required")
    sp.add_argument("--force", action="store_true", help="overwrite if file exists")
    sp.set_defaults(func=cmd_create)

    sp = sub.add_parser("list-recipients", help="print recipient ids, one per line")
    sp.add_argument("path")
    sp.set_defaults(func=cmd_list_recipients)

    sp = sub.add_parser("reader", help="modify recipient list and re-encrypt")
    sp.add_argument("path")
    sp.add_argument("--add", action="append", help="add recipient id (repeatable)")
    sp.add_argument("--delete", action="append", help="remove recipient id (repeatable)")
    sp.set_defaults(func=cmd_reader)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
