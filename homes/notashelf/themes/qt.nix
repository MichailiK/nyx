{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (builtins) elem concatStringsSep;
  inherit (lib.modules) mkIf mkMerge;

  dev = osConfig.modules.device;
  sys = osConfig.modules.system;
  cfg = osConfig.modules.style;

  acceptedTypes = ["laptop" "desktop" "hybrid" "lite"];
in {
  config = mkIf (elem dev.type acceptedTypes && sys.video.enable) {
    qt = {
      enable = true;
      platformTheme = {
        # Sets QT_QPA_PLATFORMTHEME, takes "gtk", "gtk3",  "adwaita", "kde" and a few others.
        name = mkIf cfg.forceGtk "gtk";
        package = null; # libraries associated with the platformtheme, we add those manually
      };

      style = {
        # Sets QT_STYLE_OVERRIDE, takes "gtk2, "adwaita" (and variants), "breeze", "kvantum" and a few others."
        name = mkIf cfg.useKvantum "kvantum";
        package = null; # same as above
      };
    };

    home = {
      packages = with pkgs;
        mkMerge [
          [
            # Libraries and programs to ensure
            # that QT applications load witnout issues, e.g. missing libs.
            libsForQt5.qt5ct
            kdePackages.qt6ct

            # Some KDE applications such as Dolphin try to fall back to Breeze
            # theme icons. Lets make sure they're also found.
            kdePackages.breeze-icons
          ]

          (mkIf cfg.forceGtk [
            # Libraries to ensure that "gtk" platform theme works
            # as intended after the following PR:
            # <https://github.com/nix-community/home-manager/pull/5156>
            libsForQt5.qtstyleplugins
            qt6Packages.qt6gtk2
          ])

          (mkIf cfg.useKvantum [
            # Kvantum as a library and a program to theme qt applications
            # is added here, however, this will not have an effect
            # until QT_QPA_PLATFORMTHEME has been set appropriately
            # we still write the config files for Kvantum below
            # but again, it is a no-op until the env var is set
            libsForQt5.qtstyleplugin-kvantum
            qt6Packages.qtstyleplugin-kvantum
          ])
        ];

      sessionVariables = {
        # Scaling factor for QT applications. 1 means no scaling
        QT_AUTO_SCREEN_SCALE_FACTOR = "1";

        # Use Wayland as the default backend, fallback to XCB if Wayland is not available
        QT_QPA_PLATFORM = "wayland;xcb";

        # Disable QT specific window decorations everywhere
        QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";

        # Do remain backwards compatible with QT5 if possible.
        DISABLE_QT5_COMPAT = "0";

        # Tell Calibre to use the dark theme, because the light one hurts my eyes.
        CALIBRE_USE_DARK_PALETTE = "1";
      };
    };

    # Write configuration and theme packages required KDE and Kvantum respectively.
    # Those tools aren't always used, but they are useful when the app looks for one
    # of those engines before GTK, depsite our attempts to override.
    xdg.configFile = {
      # Write ~/.config/kdeglobals based on the kdeglobals file the user has specified.
      "kdeglobals".source = cfg.qt.kdeglobals.colors;

      # Write kvantum configuration, and the theme files required by the Catppuccin theme.
      "Kvantum/kvantum.kvconfig".source = (pkgs.formats.ini {}).generate "kvantum.kvconfig" {
        General.theme = "Catppuccin";
        Applications.Catppuccin =
          concatStringsSep ", "
          ["qt5ct" "org.kde.dolphin" "org.kde.kalendar" "org.qbittorrent.qBittorrent" "hyprland-share-picker" "dolphin-emu" "Nextcloud" "nextcloud" "cantata" "org.kde.kid3-qt"];
      };

      "Kvantum/Catppuccin/Catppuccin.kvconfig".source = cfg.qt.kvantum.kvconfig;
      "Kvantum/Catppuccin/Catppuccin.svg".source = cfg.qt.kvantum.svg;
    };
  };
}
