# ChatGPT Linux

The [official Linux preview](https://learn.chatgpt.com/docs/linux/linux-app) is installed
when both `kp2pml30.agent.enable` and `kp2pml30.xserver` are enabled (`mini` and `ideapad`)
This package supports x86_64 Linux; NixOS is not officially supported upstream

After rebuilding, launch **ChatGPT** from the application menu or run `chatgpt`
The `codex://` callback is registered without changing the default web browser
Native Wayland remains opt-in via `chatgpt --ozone-platform=wayland`

## Updates

The version and hash in `default.nix` pin the official DEB; update this package
through Nix rather than installing the upstream APT repository
Read the version and filename from the [upstream package index](https://persistent.oaistatic.com/codex-app-prod/linux/deb/dists/stable/main/binary-amd64/Packages),
then fetch that versioned URL (not `latest`) to obtain its hash:

```sh
nix store prefetch-file --json --name chatgpt_amd64.deb \
	https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_VERSION_amd64.deb
```

Update both values and rebuild; check startup and sign-in after upstream changes
The build patches 2 plugin-copy paths to make copied files writable without changing
store files or following symlinks; version bumps may require refreshing these exact matches
The install check runs `plugin-copy.test.cjs` against the patched upstream helpers

The package retains upstream sandboxing and does not force a plaintext password store
