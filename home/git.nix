# Git configuration
{ config, lib, pkgs, ... }:

{
  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user.name = "Oleg Pustovit";
      user.email = "me@opustovit.com";
      core.editor = "nvim";
      push.autoSetupRemote = true;
    };
  };
}
