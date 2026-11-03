lib:
let
  dir = ../data;
  toml =
    lib.mapAttrs'
      (
        name: _:
        lib.nameValuePair (lib.removeSuffix ".toml" name) (
          builtins.fromTOML (builtins.readFile (dir + "/${name}"))
        )
      )
      (
        lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".toml" name) (builtins.readDir dir)
      );

  inherit (toml) network upstream-ids;

  machine =
    name: a:
    network.machines.${a.machine}
      or (throw "data/network.toml: address ${name} names unknown machine ${a.machine}");

  checkIds =
    kind:
    let
      ours = toml.${kind};
      upstream = upstream-ids.${kind};
      values = lib.attrValues ours;
      shared = lib.filter (n: lib.count (v: v == ours.${n}) values > 1) (lib.attrNames ours);
      clashes = lib.filter (
        n:
        (upstream ? ${n} && upstream.${n} != ours.${n})
        || lib.any (u: u.value == ours.${n} && u.name != n) (lib.attrsToList upstream)
      ) (lib.attrNames ours);
    in
    lib.assertMsg (shared == [ ]) "data/${kind}.toml: ${toString shared} share an ID"
    && lib.assertMsg (
      clashes == [ ]
    ) "data/${kind}.toml: ${toString clashes} collide with upstream-ids.toml";
in
assert checkIds "uids";
assert checkIds "gids";
toml
// {
  network = network // {
    addresses = lib.mapAttrs (name: a: a // { inherit (machine name a) ipv4 ipv6; }) network.addresses;
  };
}
