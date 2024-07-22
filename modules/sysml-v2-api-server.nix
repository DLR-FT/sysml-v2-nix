self: { config, lib, pkgs, ... }:

let
  cfg = config.services.${name};
  name = "sysml-v2-api-server";
  hocon = pkgs.formats.hocon { };
  getInstanceName = instance: "${name}-${instance}";
in
{
  options.services.${name} = {
    enable = lib.options.mkEnableOption "enable ${name} model server";
    package = lib.options.mkPackageOptionMD self.packages.${config.nixpkgs.system} "sysml-v2-api-server" { };
    instances = lib.options.mkOption {
      example = {
        play.filters.hosts.allowed = [ "." ];
        play.server.http.port = 9000;
      };
      description = lib.options.mdDoc "${name} instances to create";
      type = lib.types.attrsOf
        (lib.types.submodule {
          options.settings = lib.mkOption {
            type = lib.types.submodule {
              freeformType = hocon.type;

              options.play.http.secret.key = lib.options.mkOption {
                type = lib.types.str;
                # default = "\${PLAY_SECRET_KEY}";
                default = "BattalionUnsealedBotanistRetouchBunkbedGrab";
                # TODO this could be handled better, but is pointless as long as the server offers no means of auth anyway
                readOnly = true;
              };

              options.play.filters.hosts.allowed = lib.options.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ "." ];
              };

              options.play.server.http.port = lib.options.mkOption {
                type = lib.types.port;
                default = 9000;
              };

              options.hibernate.connection.pool_size = lib.options.mkOption {
                type = lib.types.int;
                default = 10;
              };

              options.hibernate.hbm2ddl.auto = lib.options.mkOption {
                type = lib.types.enum [
                  "none"
                  "create-only"
                  "drop"
                  "create"
                  "create-drop"
                  "validate"
                  "update"
                ];
                default = "create-only";
                description = lib.options.mdDoc ''
                  Size for the database connection pool. See
                  <https://docs.jboss.org/hibernate/orm/6.4/javadocs/org/hibernate/tool/schema/Action.html#NONE>
                  for more information.
                '';
              };
            };
          };
        });
    };
  };

  config = lib.mkIf cfg.enable
    {
      # enable postgres, ensure that a proper user exists
      services.postgresql = {
        enable = true;
        ensureDatabases = builtins.map getInstanceName (lib.attrsets.attrNames cfg.instances);
        ensureUsers = builtins.map
          (instance: {
            name = getInstanceName instance;
            ensureDBOwnership = true;
          })
          (lib.attrsets.attrNames cfg.instances);
      };


      # See https://github.com/gorenje/sysmlv2-jupyter-docker/blob/main/Dockerfile.api
      # and https://www.playframework.com/documentation/2.9.x/ProductionConfiguration
      systemd.services = lib.attrsets.mapAttrs'
        (instance: { settings }: {
          name = getInstanceName instance;
          value = {
            wantedBy = [ "multi-user.target" ];
            after = [ "postgresql.service" ];
            requires = [ "postgresql.service" ];
            serviceConfig = {
              PIDFile = "%T/RUNNING_PID";
              User = getInstanceName instance;
              Group = getInstanceName instance;
              WorkingDirectory = "%T";
              RuntimeDirectory = "%N";
              ProtectProc = "noaccess";
              PrivateDevices = true;
              PrivateTmp = true;
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

              ExecStart =
                # workaround for https://github.com/NixOS/nixpkgs/issues/329448
                let
                  moduleSettingsHocon = hocon.generate "nixos-module-settings.conf" settings;
                  finalSettings = {
                    _includes = [
                      (hocon.lib.mkInclude {
                        required = false;
                        type = "file";
                        value = "application.conf";
                      })
                      (hocon.lib.mkInclude {
                        required = false;
                        type = "file";
                        value = moduleSettingsHocon;
                      })
                    ];
                  };
                in
                ''
                  ${cfg.package}/bin/${cfg.package.meta.mainProgram} \
                    -Dconfig.file=${hocon.generate "prod.conf" finalSettings} \
                    -Dplay.server.dir=%T \
                    -Djavax.persistence.jdbc.driver=org.postgresql.Driver \
                    -Djavax.persistence.jdbc.url='jdbc:postgresql://localhost/${getInstanceName instance}?socketFactory=org.newsclub.net.unix.AFUNIXSocketFactory$SystemProperty' \
                    -Dorg.newsclub.net.unix.socket.default=/run/postgresql/.s.PGSQL.5432 \
                    -Dhibernate.dialect=org.hibernate.dialect.PostgreSQL95Dialect
                '';
            };
          };
        })
        cfg.instances;

      # create user and group for all instances
      users.users = lib.attrsets.mapAttrs'
        (instance: _: {
          name = getInstanceName instance;
          value = {
            description = "user for the ${name} model server ${instance} instance";
            shell = null;
            group = getInstanceName instance;
            isSystemUser = true;
          };
        })
        cfg.instances;
      users.groups = lib.attrsets.mapAttrs'
        (instance: _: {
          name = getInstanceName instance;
          value = { };
        })
        cfg.instances;
    };
}
