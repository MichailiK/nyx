{
  inputs,
  pkgs,
  config,
  ...
}: {
  imports = [
    ./editors
    ./kitty
    ./shell
    ./newsboat
    ./foot
    ./bottom
    ./ranger
    ./wezterm
    ./pandoc
  ];
}
