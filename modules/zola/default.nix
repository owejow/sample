{ pkgs, lib, config, ... }:
let
  cfg = config.services.zola;
  inherit (lib) types;
  q = lib.escapeShellArg;

  runtimeDir = "${config.env.DEVENV_RUNTIME}/zola";

  startScript = pkgs.writeShellApplication {
    name = "start-zola";
    text =
      # bash
      ''
        open="${toString cfg.open}"
        # Zola will pick a random port if port is already in use
        if [ "$open" = "1" ]; then 
          zola serve -O
        else
          zola serve 
        fi
      '';
  };

in {
  options.services.zola = {
    enable = lib.mkEnableOption ''
      Add zola process.
    '';

    open = lib.mkOption {
      type = types.bool;
      description = ''
        Automatically open the site in default browser
      '';
      default = false;
      defaultText = lib.literalExpression false;
      example = true;
    };
    package = lib.mkOption {
      type = types.package;
      description = ''
        The zola package to use
      '';
      default = pkgs.zola;
      defaultText = lib.literalExpression pkgs.zola;
      example = lib.literalExpression "nixpkgs-latest.zola";
    };

  };
  config = lib.mkIf cfg.enable {
    packages = [ cfg.package ];
    processes = {
      zola = {
        exec = "${startScript}/bin/start-zola";
        process-compose = {
          shutdown.signal = 15;

        };
      };
    };
  };

}
