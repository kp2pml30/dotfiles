import argparse
import json
import os
import subprocess
import sys
from urllib.parse import unquote, urlparse


def fail(msg):
    print(f"download: {msg}", file=sys.stderr)
    sys.exit(1)


def safe_name(url, given):
    name = given if given is not None else unquote(os.path.basename(urlparse(url).path))
    if not name:
        fail("cannot derive output name from URL; pass one explicitly")
    # refuse anything that could escape the current directory
    if name != os.path.basename(name) or name in (".", ".."):
        fail(f"unsafe output name: {name!r}")
    return name


def show_error(body):
    text = body.decode("utf-8", "replace").strip()
    if not text:
        return
    try:
        parsed = json.loads(text)
    except ValueError:
        print(text, file=sys.stderr)
    else:
        print(json.dumps(parsed, indent=2, ensure_ascii=False), file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(
        prog="download",
        description="Download a file from a URL with retry logic",
    )
    parser.add_argument(
        "url",
        help="URL to download from (must be http or https)",
    )
    parser.add_argument(
        "output",
        nargs="?",
        help="output filename (derived from URL if not provided)",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="overwrite existing files",
    )
    args = parser.parse_args()

    url = args.url
    scheme = urlparse(url).scheme
    if scheme not in ("http", "https"):
        fail(f"unsupported URL scheme: {scheme or '(none)'}")

    out = safe_name(url, args.output)
    if os.path.exists(out) and not args.overwrite:
        fail(f"refusing to overwrite existing file (pass --overwrite): {out}")

    proc = subprocess.run(
        [
            "curl",
            "--location",  # follow redirects
            "--fail-with-body",  # error on HTTP >=400 but keep the body
            "--retry",
            "3",
            "--retry-delay",
            "2",
            "--retry-all-errors",
            "--connect-timeout",
            "20",
            "--show-error",
            "--write-out",
            "%{stderr}\nHTTP %{http_code} (%{size_download} bytes)\n",
            "--output",
            out,
            "--",
            url,
        ]
    )
    if proc.returncode != 0:
        # on an HTTP error --fail-with-body wrote the error body to `out`;
        # surface it and drop the file so no failed transfer is left behind
        if os.path.exists(out):
            with open(out, "rb") as fh:
                show_error(fh.read())
            os.remove(out)
        sys.exit(proc.returncode)
    print(f"download: saved {out}", file=sys.stderr)


if __name__ == "__main__":
    main()
