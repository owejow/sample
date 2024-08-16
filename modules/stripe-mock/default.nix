{ pkgs, lib, config, ... }:
let
  cfg = config.services.stripe-mock;
  inherit (lib) types;
  q = lib.escapeShellArg;
  stripeMockPackage = pkgs.callPackage ./stripe-mock.nix { };

  runtimeDir = "${config.env.DEVENV_RUNTIME}/stripe-mock";
  startScript = pkgs.writeShellApplication {
    name = "start-stripe-mock";
    text =
      # bash
      ''
        http_port=${toString config.services.stripe-mock.http_port}
        https_port=${toString config.services.stripe-mock.https_port}
        mkdir -p ${q runtimeDir}
        stripe-mock -http-port $http_port  -https-port $https_port  
      '';
  };

  healthCheckScript = pkgs.writeShellApplication {
    name = "check-health-stripe-mock";
    runtimeInputs = [ pkgs.curl ];
    text =
      # bash
      ''
        # the -sSf options were taken from: https://unix.stackexchange.com/questions/84814/health-check-of-web-page-using-curl   
        #   -s silent mode, -S show errors, -f Fail silently (no output at all) on server errors.
        #
        # Using non-https to ease compatibility issues with ssh versions between server and curl
        listen_address=${config.services.stripe-mock.listen_address}
        http_port=${toString config.services.stripe-mock.http_port}

        if [ -z "$listen_address" ]; then
          listen_address="127.0.0.1"
        fi
        curl -sSf  http://$listen_address:$http_port/v1/charges -H "Authorization: Bearer sk_test_123" > /dev/null
      '';
  };

in {

  options.services.stripe-mock = {
    enable = lib.mkEnableOption ''
      Add stripe mock process.
    '';

    package = lib.mkOption {
      type = types.package;
      description = ''
        The stripe-mock to use
      '';
      default = stripeMockPackage;
      defaultText =
        lib.literalExpression "pkgs.callPackage ./stripe-mock.nix {}";
      example = lib.literalExpression ''
        pkgs.callPackage ./stripe-mock.nix
      '';
    };

    listen_address = lib.mkOption {
      type = types.str;
      description =
        "listen address. By default it listens in on all IP addresses of host.";
      default = "";
      example = "127.0.0.1";
    };

    http_port = lib.mkOption {
      type = types.port;
      description = "http_port to listen on";
      default = 12111;
      example = 4141;
    };

    https_port = lib.mkOption {
      type = types.port;
      description = "https_port to listen on";
      default = 12112;
      example = 3131;
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [ stripeMockPackage ];
    processes.stripe-mock = {
      exec = "${startScript}/bin/start-stripe-mock";

      process-compose = {
        # SIGINT (= 9) for faster shutdown. there is no state involved
        shutdown.signal = 15;

        readiness_probe = {
          # need to use exec.command inside the readiness probe.
          exec.command = "${healthCheckScript}/bin/check-health-stripe-mock";
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
}
