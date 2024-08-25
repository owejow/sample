{ pkgs, lib, config, ... }:
let
  cfg = config.services.zola;
  inherit (lib) types;
  interface = "127.0.0.1";
  zola_port = 1111;
  q = lib.escapeShellArg;

  runtimeDir = "${config.env.DEVENV_RUNTIME}/zola";

  startScript = pkgs.writeShellApplication {
    name = "start-zola";
    text =
      # bash
      ''
        open=""
        if ${toString cfg.open} == "1"; then open="-O"; fi
        zola serve --interface ${cfg.interface} --port ${
          toString cfg.port
        } $open 
      '';
  };

  healthCheckScript = pkgs.writeShellApplication {
    name = "check-health-zola";
    runtimeInputs = [ pkgs.curl ];
    text =
      # bash
      ''
        # the -sSf options were taken from: https://unix.stackexchange.com/questions/84814/health-check-of-web-page-using-curl   
        #   -s silent mode, -S show errors, -f Fail silently (no output at all) on server errors.
        #
        # Using non-https to ease compatibility issues with ssh versions between server and curl

        curl -sSf  http://${cfg.interface}:${toString cfg.port}/ > /dev/null
      '';
  };
in {
  options.services.zola = {
    enable = lib.mkEnableOption ''
      Add zola process.
    '';

    port = lib.mkOption {
      type = types.port;
      description = ''
        The zola port to run on
      '';
      default = 1111;
      defaultText = lib.literalExpression zola_port;
      example = 2222;
    };

    interface = lib.mkOption {
      type = types.str;
      description = ''
        Interface zola binds to
      '';
      default = "127.0.0.1";
      defaultText = lib.literalExpression interface;
      example = "127.0.0.1";
    };
    open = lib.mkOption {
      type = types.bool;
      description = ''
        Automatically open the site in default browser
      '';
      default = false;
      defaultText = lib.literalExpression false;
      example = true;
    };

  };
  config = lib.mkIf cfg.enable {
    packages = [ pkgs.zola ];
    processes = {
      zola = {
        exec = "${startScript}/bin/start-zola";
        process-compose = {
          shutdown.signal = 15;
          readiness_probe = {
            # need to use exec.command inside the readiness probe.
            exec.command = "${healthCheckScript}/bin/check-health-zola";
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
  };

}
