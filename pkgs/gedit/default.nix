{ stdenv, fetchFromGitHub
, lib
, meson
, mesonEmulatorHook
, fetchurl
, python3
, pkg-config
, gtk3
, gtk-mac-integration
, glib
, libgedit-amtk
, libgedit-gtksourceview
, libgedit-tepl
, libpeas
, libxml2
, gsettings-desktop-schemas
, wrapGAppsHook3
, gtk-doc
, gobject-introspection
, docbook-xsl-nons
, ninja
, gnome
, gspell
, perl
, itstool
, desktop-file-utils
, vala
# For Markdown Preview plugin
, webkitgtk_4_0
, python312Packages
, gst_all_1
, glib-networking
}:
let
  gedit-markdown-preview = fetchFromGitHub {
    owner = "novel2430";
    repo = "gedit-markdown-preview";
    rev = "af7d61852ab26a15c811fb93dd3db2905f148302";
    sha256 = "sha256-Y3pfWI+U0CoL2pbo1lCjTk0kmzUa1bn9VDyopEHKTA8=";
  };
  libs = [
    glib
    gsettings-desktop-schemas
    gspell
    gtk3
    libgedit-amtk
    libgedit-gtksourceview
    libgedit-tepl
    libpeas
    # plugins
    webkitgtk_4_0
    python312Packages.pygobject3
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    glib-networking
  ] ++ lib.optionals stdenv.hostPlatform.isDarwin [
    gtk-mac-integration
  ];

in
stdenv.mkDerivation rec {
  pname = "gedit";
  version = "48.0";

  outputs = [ "out" "devdoc" ];

  src = fetchurl {
    url = "mirror://gnome/sources/gedit/${lib.versions.major version}/gedit-${version}.tar.xz";
    sha256 = "/g/vm3sHmRINuGrok6BgA2oTRFNS3tkWm6so04rPDoA=";
  };

  patches = [
    # We patch gobject-introspection and meson to store absolute paths to libraries in typelibs
    # but that requires the install_dir is an absolute path.
    ./correct-gir-lib-path.patch
  ];

  nativeBuildInputs = [
    desktop-file-utils
    itstool
    libxml2
    meson
    ninja
    perl
    pkg-config
    python3
    vala
    wrapGAppsHook3
    gtk-doc
    gobject-introspection
    docbook-xsl-nons
  ] ++ lib.optionals (!stdenv.buildPlatform.canExecute stdenv.hostPlatform) [
    mesonEmulatorHook
  ];

  buildInputs = libs;

  postPatch = ''
    chmod +x build-aux/meson/post_install.py
    chmod +x plugins/externaltools/scripts/gedit-tool-merge.pl
    patchShebangs build-aux/meson/post_install.py
    patchShebangs plugins/externaltools/scripts/gedit-tool-merge.pl
  '';

  postInstall = ''
    # Install Plugins
    install_dir="$out/lib/gedit/plugins"
    mkdir -p ''$install_dir
    cp ${gedit-markdown-preview}/md_preview.plugin ''$install_dir/md_preview.plugin
    cp -r ${gedit-markdown-preview}/md_preview ''$install_dir/
    # Wrapper
  '';

  # Reliably fails to generate gedit-file-browser-enum-types.h in time
  enableParallelBuilding = false;

  meta = with lib; {
    homepage = "https://gitlab.gnome.org/World/gedit/gedit";
    description = "Former GNOME text editor (With Markdown-Preview plugin)";
    license = licenses.gpl2Plus;
    platforms = platforms.unix;
    mainProgram = "gedit";
  };
}
