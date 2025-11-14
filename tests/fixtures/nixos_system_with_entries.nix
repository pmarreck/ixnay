{ config, pkgs, ... }:
{
	environment.systemPackages = with pkgs; [
		# IXNAY SYSTEM PACKAGES START - DO NOT REMOVE
			stable.bat # Editor
			unstable.ripgrep # Fast search
		# IXNAY SYSTEM PACKAGES END - DO NOT REMOVE
	];
}
