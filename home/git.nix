# Git configuration
{ config, lib, pkgs, ... }:

{
  options.snowbear.git.setIdentity = lib.mkOption {
    type = lib.types.bool;
    default = builtins.getEnv "SNOWBEAR_HOME_CONTAINER" != "1";
    description = "Whether Home Manager should write Git user.name and user.email.";
  };

  config = {
    programs.git = {
      enable = true;
      lfs.enable = true;
      settings = {
        core.editor = "nvim";
        push.autoSetupRemote = true;
      } // lib.optionalAttrs config.snowbear.git.setIdentity {
        user.name = "Oleg Pustovit";
        user.email = "me@opustovit.com";
      };
    };
  };
}
