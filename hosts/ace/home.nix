{ lib, ... }:

{
  my.hyprland.enable = true;

  # GPU in waybar (ace has an AMD iGPU, chuwi doesn't expose gpu_busy_percent)
  programs.waybar.settings.mainBar = {
    modules-right = lib.mkForce [
      "custom/left-arrow-dark"
      "pulseaudio"
      "custom/left-arrow-light"
      "custom/left-arrow-dark"
      "memory"
      "custom/left-arrow-light"
      "custom/left-arrow-dark"
      "cpu"
      "custom/left-arrow-light"
      "custom/left-arrow-dark"
      "custom/gpu"
      "custom/left-arrow-light"
      "custom/left-arrow-dark"
      "disk"
      "custom/left-arrow-light"
      "custom/left-arrow-dark"
      "tray"
    ];
    "custom/gpu" = {
      interval = 5;
      exec = "cat /sys/class/drm/card1/device/gpu_busy_percent";
      format = "GPU {}%";
    };
  };
  programs.waybar.style = lib.mkAfter ''
    #custom-gpu {
      background: #181825;
      color: #f38ba8;
      padding: 0 10px;
    }
  '';

  wayland.windowManager.hyprland.settings = {
    monitor = [
      "DP-1, 1920x1080@100hz, 0x0, 1"
      "HDMI-A-1, 1920x1080, -1920x0, 1"
    ];
    workspace = [
      "1, monitor:DP-1, default:true"
      "2, monitor:DP-1"
      "3, monitor:DP-1"
      "4, monitor:DP-1"
      "5, monitor:DP-1"
      "6, monitor:DP-1"
      "7, monitor:DP-1"
      "8, monitor:DP-1"
      "9, monitor:DP-1"
      "10, monitor:HDMI-A-1"
    ];
    env = [
      "LIBVA_DRIVER_NAME,amdgpu"
      "GBM_BACKEND,amdgpu-drm"
    ];
  };

  # Override .desktop files to prepend mullvad-exclude
  xdg.desktopEntries = {
    steam = {
      name = "Steam";
      exec = "mullvad-exclude steam %U";
      icon = "steam";
      categories = [
        "Network"
        "FileTransfer"
        "Game"
      ];
      genericName = "Steam";
      comment = "Application for managing and playing games on Steam";
    };
    lutris = {
      name = "Lutris";
      exec = "mullvad-exclude lutris %U";
      icon = "lutris";
      categories = [ "Game" ];
      genericName = "Lutris";
      comment = "Open gaming platform";
    };
    rsi-launcher = {
      name = "RSI Launcher";
      genericName = "Star Citizen Launcher";
      exec = "mullvad-exclude rsi-launcher %U";
      icon = "rsi-launcher";
      terminal = false;
      categories = [ "Game" ];
      mimeType = [ "application/x-rsi-launcher" ];
    };
    "org.prismlauncher.PrismLauncher" = {
      name = "PrismLauncher";
      exec = "mullvad-exclude prismlauncher %U";
      icon = "prismlauncher";
      categories = [ "Game" ];
      genericName = "Minecraft Launcher";
      comment = "A custom launcher for Minecraft";
    };
    "com.moonlight_stream.Moonlight" = {
      name = "Moonlight";
      exec = "mullvad-exclude moonlight %U";
      icon = "moonlight";
      categories = [ "Game" ];
      genericName = "Game Streaming Client";
      comment = "Stream games from a Sunshine/GameStream host";
    };
    discord = {
      name = "Discord";
      exec = "mullvad-exclude discord %U";
      icon = "discord";
      categories = [
        "Network"
        "InstantMessaging"
        "Chat"
      ];
      genericName = "Discord";
      comment = "Voice, Video and Text Chat";
    };
  };
}
