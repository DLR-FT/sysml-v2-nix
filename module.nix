self: { config, lib, pkgs, ... }:

let
  cfg = config.services.${name};
  name = "sysml-v2-api-server";

  configGenerator = pkgs.writeShellApplication {
    name = "generate-production-conf";
    text = ''
      rm --force -- prod.conf
      umask 177
      cat << EOF > prod.conf
      include "application.conf"
      play.http.secret.key="$(head -c 32 /dev/random | base64)"
      EOF
    '';
  };
in
{
  options.services.${name} = with lib; {
    enable = options.mkEnableOption "enable ${name} model server";
    package = options.mkPackageOptionMD self.packages.${config.nixpkgs.system} "sysml-v2-api-server" { };

    port = options.mkOption {
      type = types.port;
      default = 9000;
      description = mdDoc "Port to run ${name} under";
    };
  };

  config = lib.mkIf cfg.enable {

    # enable postgres, ensure that a proper user exists
    services.postgresql = {
      enable = true;
      ensureDatabases = [ name ];
      ensureUsers = [
        {
          inherit name;
          ensureDBOwnership = true;
        }
      ];
    };


    # See https://github.com/gorenje/sysmlv2-jupyter-docker/blob/main/Dockerfile.api
    # and https://www.playframework.com/documentation/2.9.x/ProductionConfiguration
    systemd.services.${name} = {
      wantedBy = [ "multi-user.target" ];
      after = [ "postgresql.service" ];
      requires = [ "postgresql.service" ];
      serviceConfig = {
        PIDFile = "%S/%N/RUNNING_PID";
        User = name;
        Group = name;
        WorkingDirectory = "%S/%N";
        RuntimeDirectory = "%N";
        ReadWritePaths = [ "%S/%N" ];
        ProtectProc = "noaccess";
        PrivateDevices = true;
        ProtectHostname = true;
        ProtectClock = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        ReadOnlyPaths = "/nix/store";
        Restart = "always";

        # See http://serverfault.com/a/695863
        SuccessExitStatus = 143;
        ExecStartPre = "${configGenerator}/bin/${configGenerator.meta.mainProgram}";
        ExecStart = ''
          ${cfg.package}/bin/${cfg.package.meta.mainProgram} \
            -Dconfig.file=prod.conf \
            -Dplay.server.dir=%S/%N \
            -Dplay.server.http.port=${builtins.toString cfg.port} \
            -Djavax.persistence.jdbc.driver=org.postgresql.Driver \
            -Djavax.persistence.jdbc.url='jdbc:postgresql://localhost/${name}?socketFactory=org.newsclub.net.unix.AFUNIXSocketFactory$SystemProperty' \
            -Dorg.newsclub.net.unix.socket.default=/run/postgresql/.s.PGSQL.5432
        '';
      };
    };

    # create statedir
    systemd.tmpfiles.rules = [
      "d '%S/${name}' 0750 ${name} ${name} - -"
    ];

    # create user and group
    users.users.${name} = {
      description = "{name} model server";
      home = "/var/lib/${name}";
      useDefaultShell = true;
      group = name;
      isSystemUser = true;
    };
    users.groups.${name} = { };
  };
}
