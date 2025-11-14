{ config, pkgs, ... }:
{
	environment = {
		variables = {
			EDITOR = "nvim";
		};
		systemPackages = with pkgs; [
			wget
		];
	};
}
