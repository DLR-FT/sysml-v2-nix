self: { config, lib, pkgs, ... }:

let
  cfg = config.services.${moduleName};
  moduleName = "sysml-v2-api-server";
  hocon = pkgs.formats.hocon { doCheck = false; };
  javaProperties = pkgs.formats.javaProperties { };
  getInstanceName = instance: "${moduleName}-${instance}";
in
{
  options.services.${moduleName} = {
    enable = lib.options.mkEnableOption "enable ${moduleName} model server";
    package = lib.options.mkPackageOptionMD self.packages.${config.nixpkgs.system} "sysml-v2-api-server" { };
    instances = lib.options.mkOption {
      example = {
        play.filters.hosts.allowed = [ "." ];
        play.server.http.port = 9000;
      };
      description = lib.options.mdDoc "${moduleName} instances to create";
      type = lib.types.attrsOf
        (lib.types.submodule {

          # java system properties
          options.systemProperties = lib.options.mkOption {
            type = lib.types.submodule {
              freeformType = javaProperties.type;

              options."hibernate.connection.pool_size" = lib.options.mkOption {
                type = lib.types.int;
                default = 10;
              };

              options."hibernate.hbm2ddl.auto" = lib.options.mkOption {
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

          # play settings
          options.play = lib.options.mkOption {
            type = lib.types.submodule {
              freeformType = hocon.type;

              options.http.secret.key = lib.options.mkOption {
                type = lib.types.str;
                default = "BattalionUnsealedBotanistRetouchBunkbedGrab";
                # TODO this could be handled better, but is pointless as long as the server offers no means of auth anyway
                # default = "\${PLAY_SECRET_KEY}";
                readOnly = true;
              };

              options.filters.hosts.allowed = lib.options.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ "." ];
              };

              options.server.http.port = lib.options.mkOption {
                type = lib.types.port;
                default = 9000;
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
        (instance: { play, systemProperties }:
          let

            # Collect all hocon settings, and put them in a hocon config file
            # Contains workaround for https://github.com/NixOS/nixpkgs/issues/329448
            # by generating an intermediate hocon file
            moduleSettingsHocon = hocon.generate "nixos-module-settings.conf" { inherit play; };
            finalSettings = {
              _includes = [
                (hocon.lib.mkInclude {
                  required = true;
                  type = "file";
                  value = cfg.package + "/conf/application.conf";
                })
                (hocon.lib.mkInclude {
                  required = true;
                  type = "file";
                  value = moduleSettingsHocon;
                })
              ];
            };
            finalHocon = hocon.generate "prod.conf" finalSettings;

            # Merge Java System Properties
            # TODO this is a terribly leaky abstraction, why doesn't Java have a reliable way
            # to specify system properties via a file :(
            finalSystemProperties = {
              "config.file" = "${finalHocon}";
              "play.server.dir" = "%T";
              "javax.persistence.jdbc.driver" = "org.postgresql.Driver";
              "javax.persistence.jdbc.url" = "'jdbc:postgresql://localhost/${getInstanceName instance}?socketFactory=org.newsclub.net.unix.AFUNIXSocketFactory$SystemProperty'";
              "org.newsclub.net.unix.socket.default" = "/run/postgresql/.s.PGSQL.5432";
              "hibernate.dialect" = "org.hibernate.dialect.PostgreSQL95Dialect";
            } // systemProperties;

            args = lib.strings.concatStringsSep " \\\n  " (
              lib.attrsets.mapAttrsToList (name: value: "-D${name}=${builtins.toString value}") finalSystemProperties
            );
          in
          {
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
                ExecStart = "${lib.meta.getExe cfg.package} ${args}";
              };
            };
          })
        cfg.instances;

      # create user and group for all instances
      users.users = lib.attrsets.mapAttrs'
        (instance: _: {
          name = getInstanceName instance;
          value = {
            description = "user for the ${moduleName} model server ${instance} instance";
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
