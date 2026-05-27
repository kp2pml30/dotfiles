# YubiKey GPG Key Management

## Overview

Guide for managing GPG keys stored on a YubiKey, including renewal, generation, and cleanup of signing subkeys.

## Master Key

Fingerprint: `1ADB 14DE 7C1E 022B 95D5  AC86 8ABC 3800 D390 8C86`
Key ID: `8ABC3800D3908C86`

## Key Concepts

- **Master key** (`sec>`): Lives on the YubiKey. The `>` indicates a stub pointing to the card. Required for generating/signing new subkeys.
- **Subkeys** (`ssb>`): Also on the YubiKey. Used for signing `[S]`, encryption `[E]`, and authentication `[A]`.
- GPG hides expired keys by default. Use `--list-options show-unusable-subkeys` to reveal them.

## Common Tasks

### Listing keys (including expired)

```bash
gpg --list-keys --keyid-format long --list-options show-unusable-subkeys,show-unusable-uids <MASTER_KEY_ID>
```

### Checking what's on the YubiKey

```bash
gpg --card-status
```

### Generating a new signing subkey

```bash
gpg --edit-key <MASTER_KEY_ID>
```

At the `gpg>` prompt:

```
addkey
```

- Select **EdDSA (sign only)**
- Set expiration (e.g., `1y`)
- The YubiKey may require **touch** during entropy generation — watch for the blinking light
- Keep typing / moving mouse to generate entropy
- Type `save` when done

### Exporting public key (e.g., for GitHub)

```bash
gpg --armor --export <MASTER_KEY_ID>
```
