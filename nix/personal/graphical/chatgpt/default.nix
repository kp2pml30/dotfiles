{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  asar,
  coreutils,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  git,
  glib,
  gtk3,
  libgbm,
  libGL,
  libnotify,
  libpulseaudio,
  libsecret,
  libusb1,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  nspr,
  nss,
  openssl,
  pango,
  pipewire,
  systemdLibs,
  tpm2-tss,
  vulkan-loader,
  xdg-utils,
  xz,
  zlib,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "chatgpt";
  version = "26.1021.22027";

  src = fetchurl {
    name = "chatgpt_amd64.deb";
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${finalAttrs.version}_amd64.deb";
    hash = "sha256-6wgxxzTxVPk/jrzw4X0RjaDep9wXN9xhoecURDdb8ZA=";
  };

  nativeBuildInputs = [
    dpkg
    asar
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];
  buildInputs = [
    alsa-lib
    at-spi2-atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libgbm
    libGL
    libusb1
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    openssl
    pango
    stdenv.cc.cc.lib
    systemdLibs
    tpm2-tss
    zlib
  ];
  # Chromium loads these with dlopen rather than linking them directly.
  runtimeDependencies = map lib.getLib [
    gtk3
    libGL
    libnotify
    libpulseaudio
    libsecret
    pipewire
    systemdLibs
  ];
  # Upstream also bundles unused musl variants of its native Node addons.
  autoPatchelfIgnoreMissingDeps = [ "libc.musl-x86_64.so.1" ];

  dontUnpack = true;
  dontBuild = true;
  dontStrip = true;
  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    dpkg-deb -x $src unpacked
    mkdir -p $out/bin $out/lib $out/share
    cp -r unpacked/usr/lib/chatgpt $out/lib/
    cp -r unpacked/usr/share/{applications,doc,metainfo,pixmaps} $out/share/

    # Bundled plugins are copied with Nix store modes, then edited by the app.
    asar extract $out/lib/chatgpt/resources/app.asar app
    substituteInPlace app/.vite/build/main-*.js \
      --replace-fail 'await A.default.cp(e,t,{recursive:!0,verbatimSymlinks:!0});return' \
        'await A.default.cp(e,t,{recursive:!0,verbatimSymlinks:!0});await sie("${coreutils}/bin/chmod",["-R","-P","--no-dereference","u+w","--",t]);return' \
      --replace-fail 'await A.default.cp(n.cwd,e,{recursive:!0}),process.platform' \
        'await A.default.cp(n.cwd,e,{recursive:!0}),await sie("${coreutils}/bin/chmod",["-R","-P","--no-dereference","u+w","--",e]),process.platform'
    asar pack --unpack='*.node' app $out/lib/chatgpt/resources/app.asar

    # Use GTK themes; the optional Chromium Qt shims require separate Qt runtimes.
    rm $out/lib/chatgpt/libqt5_shim.so $out/lib/chatgpt/libqt6_shim.so
    rm $out/lib/chatgpt/libvulkan.so.1
    ln -s ${lib.getLib vulkan-loader}/lib/libvulkan.so.1 $out/lib/chatgpt/libvulkan.so.1

    substituteInPlace $out/share/applications/chatgpt.desktop \
      --replace-fail 'Exec=chatgpt %U' "Exec=$out/bin/chatgpt %U"

    runHook postInstall
  '';

  preFixup = ''
    makeWrapper $out/lib/chatgpt/ChatGPT $out/bin/chatgpt \
      "''${gappsWrapperArgs[@]}" \
      --suffix PATH : ${
        lib.makeBinPath [
          git
          glib
          xdg-utils
          xz
        ]
      }
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    for main in app/.vite/build/main-*.js; do
      CHATGPT_MAIN="$main" $out/lib/chatgpt/resources/cua_node/bin/node \
        --test ${./plugin-copy.test.cjs}
    done
    runHook postInstallCheck
  '';

  meta = {
    description = "Official ChatGPT desktop app for Linux";
    homepage = "https://learn.chatgpt.com/docs/linux/linux-app";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "chatgpt";
    platforms = [ "x86_64-linux" ];
  };
})
