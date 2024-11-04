{ stdenv, fetchurl
, buildFHSUserEnvBubblewrap
, writeShellScript
, makeDesktopItem
, writeShellScriptBin
, rpmextract
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
, openssl
, jack2
}:
let
  libraries = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    mesa
    nss
    pango
    xdg-desktop-portal
    xdg-user-dirs
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXrandr
    xorg.xcbutilimage
    xorg.xcbutilkeysyms
    xorg.xcbutilrenderutil
    xorg.xcbutilwm
    xorg.libXcomposite
    cairo
    gtk3
    gtk4
    libglvnd
    libpulseaudio
    libva
    pciutils
    udev
    libxkbcommon
    openssl
    jack2
  ];

  _lib_uos = "libuosdevicea";
  _pkgname = "wechat-universal";
  xdg-dir = "${xdg-user-dirs}/bin";
  ver = "4.0.0.21";
  
  # From https://github.com/7Ji-PKGBUILDs/wechat-universal-bwrap
  # Adapted from https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=wechat-universal-bwrap
  wechat-universal-license = stdenv.mkDerivation {
    pname = "${_pkgname}-license";
    version = "0.0.1";
    src = builtins.fetchGit {
      url = "https://github.com/7Ji-PKGBUILDs/wechat-universal-bwrap.git"; 
      ref = "master";
      rev = "5e8ad25218b82b9bbacb0bd43dce2feb85998889";
    };

    buildPhase = ''
      echo "Building ${_lib_uos}.so stub by Zephyr Lykos..."
      mv libuosdevicea.Makefile Makefile
      make
    '';
    installPhase = ''
      mkdir -p $out
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
      # url = "https://mirrors.opencloudos.tech/opencloudos/9.2/extras/x86_64/os/Packages/wechat-beta_${version}_amd64.rpm";
      url = "https://pro-store-packages.uniontech.com/appstore/pool/appstore/c/com.tencent.wechat/com.tencent.wechat_${version}_amd64.deb";
      # hash = "sha256-/5fXEfPHHL6G75Ph0EpoGvXD6V4BiPS0EQZM7SgZ1xk=";
      hash = "sha256-1tO8ARt2LuCwPz7rO25/9dTOIf9Rwqc9TdqiZTTojRk=";
    };
    
    nativeBuildInputs = [
      # rpmextract
      dpkg
      makeWrapper
      autoPatchelfHook
    ];
    buildInputs = libraries;

    # unpackCmd = "rpmextract $src";
    unpackCmd = "dpkg -x $src .";
    sourceRoot = ".";

    installPhase = ''
      mkdir -p $out
      # mv opt/wechat-beta opt/${_pkgname}
      cp -r opt $out
      rm $out/opt/apps/com.tencent.wechat/files/libuosdevicea.so
    '';
  };

  
  startScript = writeShellScript "wechat-start" ''
    export QT_QPA_PLATFORM=xcb
    if [[ ''${XMODIFIERS} =~ fcitx ]]; then
      export QT_IM_MODULE=fcitx
      export GTK_IM_MODULE=fcitx
    elif [[ ''${XMODIFIERS} =~ ibus ]]; then
      export QT_IM_MODULE=ibus
      export GTK_IM_MODULE=ibus
      export IBUS_USE_PORTAL=1
    fi
    exec ${wechat-universal-src}/opt/apps/com.tencent.wechat/files/wechat
  '';

  # Adapted from https://aur.archlinux.org/cgit/aur.git/tree/fake_dde-file-manager?h=wechat-universal-bwrap
  fake-dde-file-manager = writeShellScriptBin "dde-file-manager" ''
    _show_item=""
    _item=""
    for _arg in "''$@"; do
      if [[ "''${_arg}" == --show-item ]]; then
          _show_item='y'
      else
          [[ -z "''${_item}" ]] && _item="''${_arg}"
      fi
    done
    if [[ "''${_show_item}" ]]; then
      _path=$(readlink -f -- "''${_item}") # Resolve this to absolute path that's same across host / guest
      echo "Fake deepin file manager: dbus-send to open ''${_path} in file manager" 
      if [[ -d "''${_path}" ]]; then 
          # WeChat pass both files and folders in the same way, if we use ShowItems for folders, 
          # it would open that folder's parent folder, which is not right.
          _object=ShowFolders
          _target=folders
      else
          _object=ShowItems
          _target=items
      fi
      exec dbus-send --print-reply --dest=org.freedesktop.FileManager1 \
          /org/freedesktop/FileManager1 \
          org.freedesktop.FileManager1."''${_object}" \
          array:string:"file://''${_path}" \
          string:fake-dde-file-manager-show-"''${_target}"
      # We should not fall to here, but add a fallback anyway
      echo "Fake deepin file manager: fallback: xdg-open to show ''${_path} in file manager"
      exec xdg-open "''${_path}"
    else
      echo "Fake deepin file manager: xdg-open with args ''$@"
      exec xdg-open "''$@"
    fi
  '';
  fhs = buildFHSUserEnvBubblewrap {
    name = "${_pkgname}";

    targetPkgs = 
      pkgs: [
        fake-dde-file-manager
        wechat-universal-license
        wechat-universal-src
      ] 
      ++ 
      libraries;

    runScript = startScript;

    extraPreBwrapCmds = ''
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

    '';

    extraBwrapArgs = [
      "--tmpfs /home"
      "--tmpfs /root"
      "--bind \${WECHAT_HOME_DIR} \${HOME}"
      "--bind \${WECHAT_FILES_DIR} \${WECHAT_FILES_DIR}"
      "--chdir $HOME"
      "--setenv QT_QPA_PLATFORM xcb"
      # "--setenv QT_AUTO_SCREEN_SCALE_FACTOR 1"

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
  
  buildInputs = libraries;

  nativeBuildInputs = [
    makeWrapper
    autoPatchelfHook
    copyDesktopItems
  ];

  installPhase = ''
    mkdir -p $out/bin
    echo 'Installing icons...'
    for res in 16 32 48 64 128 256; do
        install -Dm644 \
            ${wechat-universal-src}/opt/apps/com.tencent.wechat/entries/icons/hicolor/''${res}x''${res}/apps/com.tencent.wechat.png \
            $out/share/icons/hicolor/''${res}x''${res}/apps/${_pkgname}.png
    done
    # install -DTm644 ${wechat-universal-src}/opt/${_pkgname}/icons/wechat.png $out/usr/share/icons/hicolor/256x256/apps/${_pkgname}.png
    makeWrapper ${fhs}/bin/${_pkgname} $out/bin/${pname}
    runHook postInstall
  '';

  # preFixup = ''
  #   patchelf --replace-needed libtiff.so.5 libtiff.so $out/opt/kingsoft/wps-office/office6/{libpdfmain.so,libqpdfpaint.so,qt/plugins/imageformats/libqtiff.so,addons/pdfbatchcompression/libpdfbatchcompressionapp.so}
  # '';
  
  desktopItems = [
    (makeDesktopItem {
      name = "${_pkgname}";
      desktopName = "WeChat Universal";
      exec = "${pname} %U";
      terminal = false;
      icon = "${_pkgname}";
      startupWMClass = "wechat";
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

