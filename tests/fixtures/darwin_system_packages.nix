{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    stable.git
  ];
}
