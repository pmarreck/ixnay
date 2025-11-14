{ config, pkgs, ... }:
{
	users.users.sample = {
		isNormalUser = true;
		packages = with pkgs; [
			## retroarch overrides [ disabled ]
			# unstable.nheko CVE-2024-4519[123
			bat
		];
	};
}
