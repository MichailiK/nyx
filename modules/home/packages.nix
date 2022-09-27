{ inputs, pkgs, config, ... }:

{
  nixpkgs.config.allowUnfree = true;
  home.packages = with pkgs; [
    wf-recorder
    inputs.webcord.packages.${pkgs.system}.default
    todo
    calcurse
    neofetch
    rofi-wayland
    vlc
    nordzy-icon-theme
    bottom
    wofi
    mpv
    imv
    hyperfine
    waybar
    gimp
    kdenlive
    swaybg
    slurp
    brave
    grim
    transmission-gtk
    fzf
    polymc
    pngquant
    wl-clipboard
    proxychains-ng
    exa
    ffmpeg
    unzip
    libnotify
    gnupg
    yt-dlp
    ripgrep
    rsync
    imagemagick
    unrar
    tealdeer
    killall
    du-dust
    bandwhich
    grex
    fd
    xfce.thunar
    xh
    jq
    figlet
    lm_sensors
    keepassxc
    python3
    git
    jdk
    dconf
    gcc
    rustc
    rustfmt
    cargo
  ];
}
