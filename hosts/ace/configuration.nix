{
  inputs,
  pkgs,
  pkgs-unstable,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../common.nix
  ];

  # temp
  nixpkgs.config.permittedInsecurePackages = [
    "docker-28.5.2"
  ];

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [
    "amdgpu.cwsr_enable=0" # Workaround for MES hang on Strix Point
    "amdgpu.mes_log_enable=1" # Enable MES logging for GPU crash diagnosis
    "mitigations=off" # Disable CPU security mitigations for performance
  ];
  boot.kernelPackages = pkgs.linuxPackages_cachyos; # CachyOS kernel for gaming
  hardware.firmware = [ pkgs.linux-firmware ];
  boot.initrd.kernelModules = [ "amdgpu" ];

  fonts.packages = [ pkgs.noto-fonts-cjk-sans ];

  # Networking
  networking.hostName = "ace";
  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = false; # Faster boot
  services.mullvad-vpn.enable = true;
  networking.wg-quick.interfaces.gjb = {
    configFile = "/etc/wireguard/gjb.conf";
    autostart = true;
  };
  # SSH
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  # Prevent suspend so SSH stays reachable
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  networking.firewall.allowedTCPPorts = [
    22
    25565
    27015
    28015
    28017
    7777
    8080
    9898
  ];
  networking.firewall.allowedUDPPorts = [
    25565
    27015
    28015
    28017
    7777
  ];

  # Second SSD
  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/0c83a41b-ebd6-4ad5-ae8f-f6007a671a93";
    fsType = "ext4";
    options = [
      "nofail"
      "x-systemd.device-timeout=5s"
    ];
  };

  # Graphics
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Hyprland
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  # Login greeter (no autologin — require authentication at boot)
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd hyprland";
      user = "greeter";
    };
  };

  # Virtualisation
  virtualisation.docker.enable = true;
  users.users.warsmite.extraGroups = [
    "wheel"
    "docker"
    "kvm"
  ];

  # Postgres
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    ensureDatabases = [ "gamejanitor" ];
    ensureUsers = [
      { name = "warsmite"; }
    ];
    initialScript = pkgs.writeText "pg-init" ''
      ALTER DATABASE gamejanitor OWNER TO warsmite;
    '';
  };

  # llama.cpp server (Vulkan, OpenAI-compatible API on port 8081)
  # Place GGUF files in /data/models/, symlink active model to default.gguf
  systemd.services.llama-server = {
    description = "llama.cpp inference server (Vulkan)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    environment = {
      HOME = "/var/lib/llama-server"; # Vulkan shader cache needs a writable home
    };

    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = "10s";
      DynamicUser = true;
      StateDirectory = "llama-server";
      ReadOnlyPaths = [ "/data/models" ];
      ExecStart = ''
        ${pkgs-unstable.llama-cpp-vulkan}/bin/llama-server \
          --model /data/models/default.gguf \
          --host 0.0.0.0 \
          --port 8081 \
          --gpu-layers 99 \
          --ctx-size 32768 \
          --flash-attn on
      '';
    };
  };

  # Games
  ## Star Citizen
  boot.kernel.sysctl = {
    "vm.max_map_count" = 16777216;
    "fs.file-max" = 524288;
    "vm.swappiness" = 10; # Prefer RAM over swap
    "vm.vfs_cache_pressure" = 50; # Keep file cache longer
  };

  # zram (compressed RAM swap - faster than disk)
  zramSwap = {
    enable = true;
    memoryPercent = 50; # Use up to 50% of RAM for zram
    algorithm = "zstd";
  };

  # I/O scheduler for NVMe
  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="kyber"
  '';

  # TDP cap via ryzenadj — prevents thermal runaway on the F7A's cooling.
  # Observed: stock BIOS lets cores hit 94.4°C (Tjmax=95). These limits
  # pull sustained power back enough to keep core_max under ~85°C.
  # Tune with: sudo ryzenadj --info (read current), then adjust values below.
  systemd.services.ryzenadj-tdp-cap = {
    description = "Apply ryzenadj TDP limits for thermal stability";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.ryzenadj}/bin/ryzenadj --stapm-limit=40000 --fast-limit=50000 --slow-limit=42000 --tctl-temp=85";
    };
  };

  environment.systemPackages = with pkgs; [
    # Star Citizen
    inputs.nix-citizen.packages.${pkgs.stdenv.hostPlatform.system}.rsi-launcher

    # Minecraft
    openjdk25
    prismlauncher # Unofficial Minecraft Launcher

    ryzenadj # Manual TDP tuning: sudo ryzenadj --info
    amdgpu_top
    wlr-randr
    mangohud
    lsof

    rocmPackages_6.rocm-runtime
    rocmPackages_6.rocm-smi
    rocmPackages_6.rocminfo
    pkgs-unstable.llama-cpp-vulkan

    (writeShellScriptBin "llama-switch" ''
      set -euo pipefail
      MODEL_DIR="/data/models"
      if [ -z "''${1:-}" ]; then
        echo "Available models:"
        ls -1 "$MODEL_DIR"/*.gguf 2>/dev/null | xargs -I{} basename {}
        echo ""
        echo "Usage: llama-switch <model.gguf>"
        exit 1
      fi
      if [ ! -f "$MODEL_DIR/$1" ]; then
        echo "Error: $MODEL_DIR/$1 not found"
        exit 1
      fi
      ln -sf "$MODEL_DIR/$1" "$MODEL_DIR/default.gguf"
      sudo systemctl restart llama-server
      echo "Switched to $1"
    '')

    # Game streaming client (Windows PC runs Sunshine as host)
    moonlight-qt

    # Monero
    monero-gui

    quickemu
    bubblewrap

    # Gamejanitor CLI
    inputs.gamejanitor.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # Extend sudo password cache to 1 hour
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=60
  '';

  ## Steam
  programs.steam.enable = true;
  programs.steam.gamescopeSession.enable = true;
  programs.gamemode.enable = true;
  programs.gamescope.enable = true;

  # Home Manager
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
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
