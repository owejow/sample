{ pkgs, lib, config, ... }:
let
  cfg = config.services.phoenix;
  inherit (lib) types;
  listen_address = "127.0.0.1";
  phoenix_port = 4000;
  q = lib.escapeShellArg;

  runtimeDir = "${config.env.DEVENV_RUNTIME}/phoenix";

  startScript = pkgs.writeShellApplication {
    name = "start-phoenix";
    text =
      # bash
      ''
        mix phx.server
      '';
  };

  healthCheckScript = pkgs.writeShellApplication {
    name = "check-health-phoenix";
    runtimeInputs = [ pkgs.curl ];
    text =
      # bash
      ''
        # the -sSf options were taken from: https://unix.stackexchange.com/questions/84814/health-check-of-web-page-using-curl   
        #   -s silent mode, -S show errors, -f Fail silently (no output at all) on server errors.
        #
        # Using non-https to ease compatibility issues with ssh versions between server and curl

        curl -sSf  http://${listen_address}:${
          toString phoenix_port
        }/ > /dev/null
      '';
  };
in {
  options.services.phoenix = {
    enable = lib.mkEnableOption ''
      Add phoenix mock process.
    '';

    db_role = lib.mkOption {
      type = types.str;
      description = ''
        The database role to use to use
      '';
      default = "postgres";
      defaultText = lib.literalExpression "postgres";
      example = "myrole";
    };

    db_password = lib.mkOption {
      type = types.str;
      description = ''
        The database role to use to use
      '';
      default = "postgres";
      defaultText = lib.literalExpression "postgres";
      example = "mypassword";
    };

  };
  config = lib.mkIf cfg.enable {
    languages.elixir.enable = true;

    packages = [ pkgs.git pkgs.rustc pkgs.cargo ]
      ++ (lib.optionals pkgs.stdenv.isLinux [
        # For ExUnit Notifier on Linux.
        pkgs.libnotify

        # For file_system on Linux.
        pkgs.inotify-tools
        # necessary for alpine linux to work properly
        pkgs.glibcLocales
      ] ++ lib.optionals pkgs.stdenv.isDarwin [
        # For ExUnit Notifier on macOS.
        pkgs.terminal-notifier
        pkgs.libiconv
        # For file_system on macOS.
        pkgs.darwin.apple_sdk.frameworks.CoreFoundation
        pkgs.darwin.apple_sdk.frameworks.CoreServices
      ]);

    services.postgres = {
      enable = true;
      initialScript = ''
        CREATE ROLE ${config.services.phoenix.db_role} WITH LOGIN PASSWORD '${config.services.phoenix.db_password}' SUPERUSER;
      '';
    };

    #"cd ${config.services.phoenix.app_name} && mix phx.server";
    processes = {
      phoenix-node-dependencies = {
        exec = "[ -f assets/package.json ] && cd assets && npm install";
      };
      phoenix-hex-dependency = { exec = "mix local.hex --force"; };
      phoenix-rebar-dependency = { exec = "mix local.rebar --force"; };
      phoenix-dependencies = {
        exec = "mix setup";
        process-compose = {
          depends_on = {
            phoenix-node-dependencies = {
              condition = "process_completed_successfully";
            };
            phoenix-hex-dependency = {
              condition = "process_completed_successfully";
            };
            phoenix-rebar-dependency = {
              condition = "process_completed_successfully";
            };
          };
        };
      };
      phoenix = {
        exec = "${startScript}/bin/start-phoenix";

        process-compose = {
          # SIGINT (= 9) for faster shutdown. there is no state involved
          shutdown.signal = 15;
          depends_on = {
            phoenix-dependencies = {
              condition = "process_completed_successfully";
            };
          };

          readiness_probe = {
            # need to use exec.command inside the readiness probe.
            exec.command = "${healthCheckScript}/bin/check-health-phoenix";
            initial_delay_seconds = 2;
            period_seconds = 10;
            timeout_seconds = 4;
            success_threshold = 1;
            failure_threshold = 5;
          };

          # https://github.com/F1bonacc1/process-compose#-auto-restart-if-not-healthy
          availability.restart = "on_failure";
        };
      };
    };

    env = {
      MIX_HOME = "${runtimeDir}/.mix";
      MIX_ARCHIVES = "${runtimeDir}/archives";
      HEX_HOME = "${runtimeDir}/.hex";
    };

    enterShell = ''
      export PATH=$MIX_HOME/bin:$PATH
      export PATH=$HEX_HOME/bin:$PATH
      export PATH=$MIX_HOME/escripts:$PATH
    '';
  };
}
