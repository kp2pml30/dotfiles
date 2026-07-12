# Syncthing peers that are not NixOS hosts (phones, laptops, etc.). Their device
# IDs can't be derived from the flake, so record them by tailnet name here.
# These are roaming clients: they dial mini, so their dial address is "dynamic"
# (set in sync-files.nix, not here).
{
  power-armor-18.syncthing = "5FZUTH7-VBJZZAN-LX5JL3R-KRMWNXA-VWNLLDI-AUX4HY5-3FSYG7T-NMQYOQV";
}
