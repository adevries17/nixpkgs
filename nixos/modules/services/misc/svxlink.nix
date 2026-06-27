{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.svxlink;

  # Helper to convert attribute set to INI format
  generateIni =
    settings:
    let
      toIniValue = v: if lib.isBool v then (if v then "1" else "0") else toString v;
    in
    lib.concatStringsSep "\n\n" (
      lib.mapAttrs (
        section: values:
        let
          sectionHeader = "[${section}]";
          sectionBody = lib.concatStringsSep "\n" (
            lib.mapAttrs (key: value: "${key}=${toIniValue value}") values
          );
        in
        "${sectionHeader}\n${sectionBody}"
      ) settings
    );
in
{
  options.services.svxlink = {
    enable = lib.mkEnableOption "SvxLink service";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.svxlink;
      description = "The SvxLink package to use.";
    };

    user = lib.mkOption {
      type = lib.types.user;
      default = "svxlink";
      description = "The user under which SvxLink will run.";
    };

    group = lib.mkOption {
      type = lib.types.userGroup;
      default = "audio";
      description = "The group under which SvxLink will run. It should have access to the necessary hardware (e.g., audio, GPIO).";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = { };
      description = "The configuration settings for SvxLink in INI format. This is a nested attribute set where the first level represents sections and the second level represents key-value pairs.";
    };

    extraConfig = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Additional configuration to append to the generated svxlink.conf.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."svxlink/svxlink.conf".text =
      generateIni cfg.settings + (if cfg.extraConfig != "" then "\n\n" + cfg.extraConfig else "");

    systemd.services.svxlink = {
      description = "SvxLink service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${cfg.package}/bin/svxlink --config /etc/svxlink/svxlink.conf";
        Restart = "on-failure";
      };
    };
  };
}
