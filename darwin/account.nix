{ pkgs, config, ... }:

{
  # User account configuration for nix-darwin integration
  
  # Configure user shell and home directory for proper nix-darwin operation
  users.users.${config._module.args.userName} = {
    home = config._module.args.userHomeDarwin;
    shell = pkgs.fish;
  };
}
