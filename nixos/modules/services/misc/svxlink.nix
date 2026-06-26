{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.svxlink;
  settingsFormat = pkgs.formats.ini { };

  dataDir = "/var/lib/svxlink";
  settingsFile = "${dataDir}/svxlink.conf";

  mkSettingsFileUnsubstituted =
    settings:
    let
      pyBool = x: if x then "True" else "False";
      finalSettings = lib.mapAttrs (
        _: lib.mapAttrs (_: v: if lib.isBool v then pyBool v else v)
      ) settings;
    in
    settingsFormat.generate "svxlink-unsubstituted.conf" finalSettings;

  settingsFileUnsubstituted =
    if cfg.settings == { } then
      pkgs.writeText "svxlink-unsubstituted.conf" cfg.config
    else
      mkSettingsFileUnsubstituted cfg.settings;
in
{
  options.services.svxlink = {
    enable = lib.mkEnableOption "svxserver svx2svx repeater control software";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.svxlink;
      description = "The svxlink package.";
    };

    runAsUser = lib.mkOption {
      type = lib.types.user;
      default = "svxlink";
      description = "User to run svxserver as.";
    };

    settings = lib.mkOption {
      inherit (settingsFormat) type;
      description = "Contents of ${pkgs.writeText "svxlink.conf" ""}.";
      default = { };
    };

    config = lib.mkOption {
      type = lib.types.lines;
      description = "Contents of ${pkgs.writeText "svxlink.conf" ""}.";
      default = "";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Environment file as defined in {manpage}`systemd.exec(5)`.

        Secrets may be passed to the service without adding them to the world-readable
        Nix store, by specifying placeholder variables as the option value in Nix and
        setting these variables accordingly in the environment file.

        ```
          # snippet of svxlink-related config
          # If using envsubst in config
          some_secret = $SVX_SECRET
        ```

        ```
          # contents of the environment file
          SVX_SECRET=verysecretpassword
        ```
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = lib.xor (cfg.settings != { }) (cfg.config != "");
          message = "services.svxlink.settings and services.svxlink.config are mutually exclusive";
        }
      ];

      environment.etc."svxlink/svxlink.conf".source = settingsFile;

      systemd.services.svxserver = {
        description = "svxserver svx2svx repeater control software";
        after = [
          "network.target"
          "remote-fs.target"
          "syslog.target"
          "time.target"
        ];
        wantedBy = [ "multi-user.target" ];
        restartTriggers = [
          settingsFileUnsubstituted
        ];
        serviceConfig = {
          ExecStartPre = [
            "-${pkgs.coreutils}/bin/touch /var/log/svxserver"
            "-${pkgs.coreutils}/bin/chown ${cfg.runAsUser} /var/log/svxserver"
          ];
          ExecStart = [
            "/bin/sh"
            "-c"
            "${cfg.package}/bin/svxserver --logfile=/var/log/svxserver --config=$CFGFILE --pidfile=/run/svxserver.pid --runasuser=$RUNASUSER"
          ];
          ExecReload = "${pkgs.coreutils}/bin/kill -s HUP $MAINPID";
          Restart = "on-failure";
          TimeoutStartSec = 60;
          LimitCORE = "infinity";
          PIDFile = "/run/svxserver.pid";
          WorkingDirectory = "/etc/svxlink";
          Environment = [
            "CFGFILE=/etc/svxlink/svxlink.conf"
            "RUNASUSER=${cfg.runAsUser}"
          ];
          EnvironmentFile = lib.mkIf (cfg.environmentFile != null) cfg.environmentFile;
        };
        preStart = ''
          mkdir -p "${dataDir}"
          [ -f ${settingsFile} ] && rm -f ${settingsFile}
          old_umask=$(umask)
          umask 0177
          ${pkgs.envsubst}/bin/envsubst \
            -o ${settingsFile} \
            -i ${settingsFileUnsubstituted}
          umask $old_umask
        '';
      };
    })
  ];
}
