{ pkgs, ... }:
let
  baseSystemPackages = with pkgs; [
    git
  ];
in {
  environment.systemPackages = baseSystemPackages ++ [ curl ];
}
