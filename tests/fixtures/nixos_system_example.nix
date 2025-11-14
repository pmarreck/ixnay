{ config, pkgs, ... }:
{
	environment.systemPackages = with pkgs; [
		alacritty
		# IXNAY SYSTEM PACKAGES START - DO NOT REMOVE
		# IXNAY SYSTEM PACKAGES END - DO NOT REMOVE
	];
}
