{
  inputs,
  self,
  lib,
  ...
}: let
  inherit (lib.attrsets) mapAttrs filterAttrs;

  includedNodes = ["enyo" "helios"];

  mkNode = name: cfg: let
    inherit (cfg.pkgs.stdenv.hostPlatform) system;
    deployLib = inputs.deploy-rs.lib.${system};
  in {
    # this looks pretty goofy, I should get a simpler domain
    # it's actually hostname.namespace.domain.tld but my domain and namespace are the same
    hostname = "${name}.notashelf.notashelf.dev";
    sshOpts = ["-p" "30"];
    skipChecks = true;
    # currently only a single profile system
    profilesOrder = ["system"];
    profiles.system = {
      sshUser = "root";
      user = "root";
      path = deployLib.activate.nixos cfg;
    };
  };
  nodes = mapAttrs mkNode (filterAttrs (name: _: lib.elem name includedNodes) self.nixosConfigurations);
in {
  flake = {
    deploy = {
      autoRollback = true;
      magicRollback = true;
      inherit nodes;
    };
  };

  perSystem = {
    inputs',
    system,
    pkgs,
    ...
  }: {
    # evaluation of deployChecks is slow
    # checks = (deployPkgs.deploy-rs.lib.deployChecks self.deploy)

    apps.deploy = {
      type = "app";
      program = pkgs.writeShellScriptBin "deploy" ''
        ${inputs'.deploy-rs.packages.deploy-rs}/bin/deploy --skip-checks
      '';
    };
  };
}
