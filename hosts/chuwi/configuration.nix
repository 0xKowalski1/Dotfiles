{ inputs, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../common.nix
  ];

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "video=DSI-1:panel_orientation=right_side_up" "resume_offset=22530048" ];
  boot.resumeDevice = "/dev/disk/by-uuid/3ea1f79f-1136-4d32-b865-c7acfdecf558";  # root partition
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Networking
  networking.hostName = "chuwi";
  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = false; # Faster boot
  services.mullvad-vpn.enable = true;

  # Power
  powerManagement = {
    enable = true;
    powertop.enable = true;
  };

  # Suspend-then-hibernate on lid close
  # Suspends immediately, hibernates after timeout (zero power for long idle)
  services.logind = {
    lidSwitch = "suspend-then-hibernate";
    lidSwitchExternalPower = "suspend-then-hibernate";
  };

  systemd.sleep.extraConfig = ''
    HibernateDelaySec=5min
  '';

  # Swap file for hibernate (must be >= RAM)
  swapDevices = [{
    device = "/swapfile";
    size = 16 * 1024;  # 16GB in MB
  }];

  # Bluetooth
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # Hyprland
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Login greeter (no autologin — require authentication at boot)
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd hyprland";
      user = "greeter";
    };
  };

  # Home Manager
  home-manager = {
    extraSpecialArgs = { inherit inputs; };

    users = {
      "warsmite" =
        { ... }:
        {
          imports = [
            ./home.nix
            ../../home.nix
          ];
        };
    };
  };

  system.stateVersion = "25.05";
}
