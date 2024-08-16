{ pkgs, lib, config, ... }:
let
  cfg = config.languages.cowsay;
  q = lib.escapeShellArg;

in {
  options.languages.cowsay = {
    enable = lib.mkEnableOption ''
      Add cowsay mock process.
    '';

  };
  config = lib.mkIf cfg.enable { packages = [ pkgs.cowsay ]; };

}
