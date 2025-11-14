{ config, pkgs, ... }:
{
	users.users.sample = {
		isNormalUser = true;
		packages = with pkgs; [
			bat
			# IXNAY USER PACKAGES (sample) START - DO NOT REMOVE
			# IXNAY USER PACKAGES (sample) END - DO NOT REMOVE
		];
	};
}
