{ pkgs, userName, userHomeDarwin, ... }:

{
  users.users.${userName} = {
    home = userHomeDarwin;
    shell = pkgs.fish;
  };
}
