{ config, pkgs, ... }:

{
  home-manager.users.sample = { pkgs, ... }: {
    home.packages = with pkgs; [
      stable.git
    ];
  };
}
