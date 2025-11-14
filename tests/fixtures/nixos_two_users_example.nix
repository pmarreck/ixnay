{ config, pkgs, ... }:
{
	users.users.alpha = {
		isNormalUser = true;
		packages = with pkgs; [
			# IXNAY USER PACKAGES (alpha) START - DO NOT REMOVE
			# IXNAY USER PACKAGES (alpha) END - DO NOT REMOVE
		];
	};

	users.users.sample = {
		isNormalUser = true;
		packages = with pkgs; [
			# IXNAY USER PACKAGES (sample) START - DO NOT REMOVE
			# IXNAY USER PACKAGES (sample) END - DO NOT REMOVE
		];
	};
}
