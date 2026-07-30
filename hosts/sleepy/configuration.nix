{ inputs, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../common.nix
    #inputs.gamejanitor.nixosModules.default
  ];

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.hostName = "sleepy";
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  # SSH
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  # Remote rebuilds
  security.sudo.wheelNeedsPassword = false;

  # DDNS
  services.ddclient = {
    enable = true;
    interval = "1min";
    protocol = "duckdns";
    ssl = true;
    passwordFile = "/etc/nixos/ddns-token";
    domains = [ "bigbingchilling.duckdns.org" ];
  };

  #environment.systemPackages = [
  #  inputs.gamejanitor.packages.${pkgs.stdenv.hostPlatform.system}.default
  #];

  #services.gamejanitor = {
  #  enable = true;
  #  controller = true;
  #  worker = true;
  #  containerRuntime = "docker";
  #  bindAddress = "0.0.0.0";
  #  port = 8080;
  #  grpcPort = 9090;
  #  sftpPort = 2022;
  #  settings = {
  #    port_range_start = 27000;
  #    port_range_end = 27999;
  #  };
  #  openFirewall = true;
  #};

  # SearXNG
  services.searx = {
    enable = true;
    environmentFile = "/etc/nixos/searxng-secret";
    settings = {
      server = {
        port = 8888;
        bind_address = "0.0.0.0";
        secret_key = "$SEARX_SECRET_KEY";
      };
      search = {
        default_lang = "en";
        formats = [ "html" "json" ];
      };
    };
  };
  # Caddy reverse proxy (auto TLS via Let's Encrypt)
  #services.caddy = {
  #  enable = true;
  #  virtualHosts."warsmite.com".extraConfig = ''
  #    reverse_proxy localhost:8080
  #  '';
  #};

  networking.firewall.allowedTCPPorts = [ 8888 8080 9090 2022 2222 ];
  networking.firewall.allowedTCPPortRanges = [{ from = 27000; to = 27999; }];
  networking.firewall.allowedUDPPortRanges = [{ from = 27000; to = 27999; }];

  # User
  users.users.warsmite = {
    isNormalUser = true;
    home = "/home/warsmite";
    extraGroups = [ "wheel" ];
  };

  system.stateVersion = "25.05";
}
