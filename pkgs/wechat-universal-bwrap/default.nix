{ stdenv, fetchurl
, buildFHSUserEnvBubblewrap
, writeShellScript
, makeDesktopItem
, makeWrapper
, autoPatchelfHook
, copyDesktopItems
, lib
, alsa-lib
, at-spi2-atk
, at-spi2-core
, mesa
, nss
, pango
, xdg-desktop-portal
, xdg-user-dirs
, xorg
, cairo
, gtk3
, gtk4
, libglvnd
, libpulseaudio
, libva
, pciutils
, udev
, libxkbcommon
, dpkg
, jack2
, xhost
, nspr
, zlib
, atkmm
, libdrm
, xcbutilwm
, xcbutilimage
, xcbutilkeysyms
, xcbutilrenderutil
, wayland
, openssl
, atk
, qt6
, dbus
, cups
, libxml2
, freetype
, fontconfig
, vulkan-loader
, gdk-pixbuf
, libexif
, ffmpeg
, pulseaudio
, systemd
, libuuid
, expat
, bzip2
, glib
, libGL
, libnotify
, buildFHSEnv
}:
let
  libraries = with xorg; [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    mesa
    nss
    pango
    xdg-desktop-portal
    xdg-user-dirs
    libXcursor
    libXdamage
    libXrandr
    xcbutilimage
    xcbutilkeysyms
    xcbutilrenderutil
    xcbutilwm
    libXcomposite
    cairo
    gtk3
    gtk4
    libglvnd
    libpulseaudio
    libva
    pciutils
    udev
    libxkbcommon
    jack2
    zlib
    libX11
    libXt
    libXext
    libSM
    libICE
    libxcb
    libxshmfence
    libXi
    libXft
    libXScrnSaver
    libXcomposite
    libXdamage
    libXtst
    libnotify
    atk
    atkmm
    dbus
    cups
    gdk-pixbuf
    libexif
    ffmpeg
    libva
    freetype
    fontconfig
    libXrender
    libuuid
    expat
    glib
    nss
    nspr
    libGL
    libxml2
    libdrm
    vulkan-loader
    systemd
    wayland
    pulseaudio
    qt6.qt5compat
    openssl
    bzip2
  ];

  _lib_uos = "libuosdevicea";
  _pkgname = "wechat-universal";
  xdg-dir = "${xdg-user-dirs}/bin";
  ver = "4.0.0.21";
  
  # From https://github.com/7Ji-PKGBUILDs/wechat-universal-bwrap
  # Adapted from https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=wechat-universal-bwrap
  wechat-universal-license = stdenv.mkDerivation {
    pname = "${_pkgname}-license";
    version = "0.0.2";
    src = builtins.fetchGit {
      url = "https://github.com/7Ji-PKGBUILDs/wechat-universal-bwrap.git"; 
      ref = "master";
      rev = "e0982191c6940f1bdcae87786cf8e5badfaf65c9";
    };

    buildPhase = ''
      echo "Building ${_lib_uos}.so stub by Zephyr Lykos..."
      mv libuosdevicea.Makefile Makefile
      make
    '';
    installPhase = ''
      echo "Fixing licenses..."
      install -dm755 $out/usr/lib/license 
      install -Dm755 ${_lib_uos}.so $out/lib/license/${_lib_uos}.so
      echo "DISTRIB_ID=uos" |
          install -Dm755 /dev/stdin $out/etc/lsb-release
    '';
  };

  wechat-universal-src = stdenv.mkDerivation rec {

    pname = "${_pkgname}-source";
    version = "${ver}";

    src = fetchurl {
      url = "https://pro-store-packages.uniontech.com/appstore/pool/appstore/c/com.tencent.wechat/com.tencent.wechat_${version}_amd64.deb";
      hash = "sha256-1tO8ARt2LuCwPz7rO25/9dTOIf9Rwqc9TdqiZTTojRk=";
    };
    
    nativeBuildInputs = [
      dpkg
      makeWrapper
      autoPatchelfHook
    ];
    buildInputs = libraries;

    unpackCmd = "dpkg -x $src .";
    sourceRoot = ".";

    dontWrapQtApps = true;

    installPhase = ''
      mkdir -p $out
      mv opt/apps/com.tencent.wechat/files opt/${_pkgname}
      rm opt/${_pkgname}/${_lib_uos}.so
      cp -r opt $out
    '';
  };

  startScript = writeShellScript "wechat-start" ''
    export QT_QPA_PLATFORM=xcb
    export LD_LIBRARY_PATH=${lib.makeLibraryPath libraries}
    if [[ ''${XMODIFIERS} =~ fcitx ]]; then
      export QT_IM_MODULE=fcitx
      export GTK_IM_MODULE=fcitx
    elif [[ ''${XMODIFIERS} =~ ibus ]]; then
      export QT_IM_MODULE=ibus
      export GTK_IM_MODULE=ibus
      export IBUS_USE_PORTAL=1
    fi
    exec ${wechat-universal-src}/opt/${_pkgname}/wechat
  '';

  fhs = buildFHSUserEnvBubblewrap {
    name = "${_pkgname}";

    targetPkgs = 
      pkgs: [
        wechat-universal-license
      ];

    runScript = startScript;

    extraBuildCommands = ''
    '';

    extraPreBwrapCmds = ''
      function detectXauth() {
        if [ ! ''${XAUTHORITY} ]; then
          echo '[Warn] No ''${XAUTHORITY} detected! Do you have any X server running?'
          export XAUTHORITYpath="/$(uuidgen)/$(uuidgen)"
          ${xhost}/bin/xhost +
        else
          export XAUTHORITYpath="''${XAUTHORITY}"
        fi
        if [[ ! ''${DISPLAY} ]]; then
          echo '[Warn] No ''${DISPLAY} detected! Do you have any X server running?'
        fi
      }
      # Data folder setup
      # If user has declared a custom data dir, no need to query xdg for documents dir, but always resolve that to absolute path
      if [[ "''${WECHAT_DATA_DIR}" ]]; then
          WECHAT_DATA_DIR=$(readlink -f -- "''${WECHAT_DATA_DIR}")
      else
          XDG_DOCUMENTS_DIR="''${XDG_DOCUMENTS_DIR:-$(${xdg-dir}/xdg-user-dir DOCUMENTS)}"
          if [[ -z "''${XDG_DOCUMENTS_DIR}" ]]; then
              echo 'Error: Failed to get XDG_DOCUMENTS_DIR, refuse to continue'
              exit 1
          fi
          WECHAT_DATA_DIR="''${XDG_DOCUMENTS_DIR}/WeChat_Data"
      fi
      WECHAT_FILES_DIR="''${WECHAT_DATA_DIR}/xwechat_files"
      WECHAT_HOME_DIR="''${WECHAT_DATA_DIR}/home"
      mkdir -p "''${WECHAT_FILES_DIR}"
      mkdir -p "''${WECHAT_HOME_DIR}"
      detectXauth

    '';

    extraBwrapArgs = [
      "--tmpfs /home"
      "--tmpfs /root"
      "--bind \${WECHAT_HOME_DIR} \${HOME}"
      "--bind \${WECHAT_FILES_DIR} \${WECHAT_FILES_DIR}"
      "--chdir $HOME"
      "--setenv QT_QPA_PLATFORM xcb"
      # "--setenv QT_AUTO_SCREEN_SCALE_FACTOR 1"

      "--ro-bind-try \${XAUTHORITYpath} \${XAUTHORITYpath}"

      "--ro-bind-try \${HOME}/.fontconfig{,}"
      "--ro-bind-try \${HOME}/.fonts{,}"
      "--ro-bind-try \${HOME}/.config/fontconfig{,}"
      "--ro-bind-try \${HOME}/.local/share/fonts{,}"
      "--ro-bind-try \${HOME}/.icons{,}"
      "--ro-bind-try \${HOME}/.local/share/.icons{,}"
    ];

    unshareUser = true;
    unshareIpc = true;
    unsharePid = true;
    unshareNet = false;
    unshareUts = true;
    unshareCgroup = true;
    privateTmp = true;
  };
in
stdenv.mkDerivation rec {

  pname = "${_pkgname}-bwrap";
  version = "${ver}";

  dontUnpack = true;

  nativeBuildInputs = [
    makeWrapper
    autoPatchelfHook
    copyDesktopItems
  ];

  dontWrapQtApps = true;
  
  installPhase = ''
    mkdir -p $out/bin
    echo 'Installing icons...'
    for res in 16 32 48 64 128 256; do
        install -Dm644 \
            ${wechat-universal-src}/opt/apps/com.tencent.wechat/entries/icons/hicolor/''${res}x''${res}/apps/com.tencent.wechat.png \
            $out/share/icons/hicolor/''${res}x''${res}/apps/wechat.png
    done
    makeWrapper ${fhs}/bin/${_pkgname} $out/bin/${pname}
    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "${_pkgname}";
      desktopName = "WeChat Universal";
      exec = "${pname} %U";
      terminal = false;
      icon = "wechat";
      comment = "WeChat Universal Desktop Edition";
      categories = [ "Utility" "Network" "InstantMessaging" "Chat" ];
      keywords = [
        "wechat"
        "weixin"
        "${_pkgname}"
      ];
      extraConfig = {
        "Name[zh_CN]" = "微信 Universal";
        "Name[zh_TW]" = "微信 Universal";
        "Comment[zh_CN]" = "微信桌面版 Universal";
        "Comment[zh_TW]" = "微信桌面版 Universal";
      };
    })
  ];

  meta = with lib; {
    description = ''
      WeChat desktop with sandbox enabled 
      (Adapted from https://aur.archlinux.org/packages/wechat-universal-bwrap)
    '';
    homepage = "https://weixin.qq.com/";
    platforms = [ "x86_64-linux" ];
    license = licenses.unfreeRedistributable;
  };
}

