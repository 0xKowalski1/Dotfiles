{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  # System
  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.trusted-users = [ "warsmite" ];

  time.timeZone = "Europe/London";

  # NAS
  boot.supportedFilesystems = [ "nfs" ];

  fileSystems = lib.mkIf (config.networking.hostName != "doc") {
    "/mnt/data" = {
      device = "192.168.1.129:/data";
      fsType = "nfs";
      options = [
        "rw"
        "sync"
        "x-systemd.automount"
        "x-systemd.mount-timeout=30"
        "retry=3"
      ];
    };
  };

  #Users
  users.users.warsmite = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  # Ssh
  programs.ssh = {
    startAgent = true;
  };

  programs.nix-ld.enable = true;

  # Homelab
  networking.extraHosts = ''
    192.168.1.19 ace
    192.168.1.69 dopey
    192.168.1.102 sleepy
    192.168.1.129 doc
    192.168.1.184 grumpy
    51.68.38.150 bashful
    209.141.46.246 sneezy
  '';

  # Git
  programs.git.enable = true;

  # Tmux
  programs.tmux = {
    enable = true;
    baseIndex = 1; # Make windows start at 1
    escapeTime = 0; # Make neovim snappier
    keyMode = "vi";

    plugins = with pkgs.tmuxPlugins; [
      inputs.minimal-tmux.packages.${pkgs.stdenv.hostPlatform.system}.default
      resurrect
      continuum
      yank
      extrakto
      open
    ];

    # Plugin settings must be set before the plugins are sourced
    extraConfigBeforePlugins = ''
      set -g @resurrect-strategy-nvim 'session'
      set -g @resurrect-processes 'ssh ".claude-unwrapped"'
      set -g @continuum-restore 'on'
      set -g @extrakto_copy_key 'tab'
      set -g @extrakto_insert_key 'enter'

      # Battery + clock appended after the session name on the right. tmux
      # re-runs #(...) every status-interval; tmux-battery is silent on hosts
      # without a battery, so this is a no-op on desktops/servers.
      set -g @minimal-tmux-status-right-extra ' #(tmux-battery) %H:%M'

      # Wayland clipboard wiring — skipped on TTY-only hosts (thinkpad),
      # where wl-copy has no display to talk to
      if-shell '[ -n "$WAYLAND_DISPLAY" ]' {
        set -g @extrakto_clip_tool 'wl-copy'
        set -g @yank_selection_mouse 'clipboard'
        set -g @override_copy_command 'wl-copy'
      }
    '';

    extraConfig = ''
      # Terminal & color
      set -g default-terminal "tmux-256color"
      # Only advertise 24-bit colour where a compositor backs it. On bare-TTY
      # hosts (thinkpad) the Linux console is 16-colour, so advertising RGB
      # just makes truecolor themes dither to mud.
      if-shell '[ -n "$WAYLAND_DISPLAY" ]' {
        set -sa terminal-features ',xterm-256color:RGB'
      }

      # General
      set -g mouse on
      set -g focus-events on
      set -g history-limit 50000
      set -g renumber-windows on
      set -g status-interval 15 # Refresh status bar (battery) every 15s

      # Pane borders (Catppuccin)
      set -g pane-border-style 'fg=#313244'
      set -g pane-active-border-style 'fg=#b4befe'

      # Copy mode highlight (Catppuccin)
      set -g mode-style 'fg=#cdd6f4,bg=#45475a'

      # Mouse-drag copy to system clipboard (Wayland only, overrides yank plugin)
      if-shell '[ -n "$WAYLAND_DISPLAY" ]' {
        bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "wl-copy"
      }

      # M is ALT in this context
      # Manage Windows
      bind-key -n M-X kill-window

      ## Switch to specific window by number
      bind-key -n M-1 run-shell "tmux select-window -t :=1 || tmux new-window -t 1 -c ~"
      bind-key -n M-2 run-shell "tmux select-window -t :=2 || tmux new-window -t 2 -c ~"
      bind-key -n M-3 run-shell "tmux select-window -t :=3 || tmux new-window -t 3 -c ~"
      bind-key -n M-4 run-shell "tmux select-window -t :=4 || tmux new-window -t 4 -c ~"
      bind-key -n M-5 run-shell "tmux select-window -t :=5 || tmux new-window -t 5 -c ~"
      bind-key -n M-6 run-shell "tmux select-window -t :=6 || tmux new-window -t 6 -c ~"
      bind-key -n M-7 run-shell "tmux select-window -t :=7 || tmux new-window -t 7 -c ~"
      bind-key -n M-8 run-shell "tmux select-window -t :=8 || tmux new-window -t 8 -c ~"
      bind-key -n M-9 run-shell "tmux select-window -t :=9 || tmux new-window -t 9 -c ~"
      bind-key -n M-0 run-shell "tmux select-window -t :=10 || tmux new-window -t 10 -c ~"

      # Pane Management
      bind-key -n M-x kill-pane
      ## Pane Splitting
      bind-key -n M-h split-window -h -c "#{pane_current_path}"
      bind-key -n M-v split-window -v -c "#{pane_current_path}"

      ## Navigate panes
      bind-key -n M-Left select-pane -L
      bind-key -n M-Right select-pane -R
      bind-key -n M-Up select-pane -U
      bind-key -n M-Down select-pane -D

      ## Resize panes
      bind-key -n -r M-S-Left resize-pane -L 5
      bind-key -n -r M-S-Right resize-pane -R 5
      bind-key -n -r M-S-Up resize-pane -U 5
      bind-key -n -r M-S-Down resize-pane -D 5

      ## Swap panes
      bind-key -n M-'{' swap-pane -U
      bind-key -n M-'}' swap-pane -D

      ## Zoom pane (toggle fullscreen)
      bind-key -n M-z resize-pane -Z

      # Scrollback: kernels >= 5.9 dropped Linux-console scrollback
      # (Shift+PgUp), so tmux copy-mode is the only scrollback on bare-TTY
      # hosts. PgUp at a prompt would otherwise fall through to readline,
      # which /etc/inputrc binds to beginning-of-history. Pass PgUp through
      # untouched when a full-screen app (nvim, less) owns the pane.
      bind-key -n PPage if-shell -F "#{alternate_on}" "send-keys PPage" "copy-mode -eu"
    '';
  };

  # Bash
  programs.bash = {
    shellAliases = {
      gs = "git status";
      gp = "git push";
      gl = "git log --oneline";
      sandbox = "ssh -t grumpy 'sudo machinectl shell warsmite@claude-sandbox'";
      claude = "mullvad-exclude claude";
    };
    interactiveShellInit = ''
      # Auto-start Tmux if not already in a session (skip root so
      # sudo -i / root TTY logins don't grab the user session)
      if [ -z "$TMUX" ] && [ "$(id -u)" -ne 0 ]; then
        tmux attach -t default || tmux new -s default
      fi
    '';
  };

  # fzf (Ctrl-R for history, Ctrl-T for file finder)
  programs.fzf = {
    keybindings = true;
    fuzzyCompletion = true;
  };
  environment.variables = {
    FZF_DEFAULT_COMMAND = "rg --files --hidden --glob '!.git'";
    FZF_DEFAULT_OPTS = lib.concatStringsSep " " [
      "--height 40%"
      "--border"
      "--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8"
      "--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc"
      "--color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
    ];
  };

  # Direnv (includes nix-direnv and bash integration by default)
  programs.direnv.enable = true;

  environment.systemPackages = with pkgs; [
    lm_sensors # Heat Sensors
    wireguard-tools

    # Terminal utilities — every host, incl. ones without home-manager
    gh # Github cli
    lftp # sftp
    ffmpeg
    openssl
    xxd
    wget
    ripgrep # fzf default command + telescope live_grep
    dnsutils # dig, nslookup
    whois
    traceroute
    nmap
    tree
    jq
    unzip
    zip
    file
    lsof
    strace
    btop
    termdown
    acpi # Battery viewer
    (writeShellScriptBin "tmux-battery" ''
      # Compact battery segment for the tmux status bar. Silent on desktops
      # and servers — acpi -b prints nothing when there is no battery.
      bat=$(acpi -b 2>/dev/null | head -1)
      [ -z "$bat" ] && exit 0

      state=$(printf '%s' "$bat" | sed -E 's/^Battery [0-9]+: ([^,]+),.*/\1/')
      pct=$(printf '%s' "$bat" | grep -oE '[0-9]+%' | head -1)
      hms=$(printf '%s' "$bat" | grep -oE '[0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
      hm=$(printf '%s' "$hms" | cut -d: -f1,2)   # HH:MM, seconds dropped
      num=$(printf '%s' "$pct" | tr -d '%')

      case "$state" in
        Discharging) sym=BAT ;;
        Charging)    sym=CHG ;;
        *)           sym=AC  ;;
      esac

      # Turn red (Catppuccin colour1) when low and unplugged.
      color=""; reset=""
      if [ "$state" = Discharging ] && [ "''${num:-100}" -le 15 ]; then
        color="#[fg=colour1]"; reset="#[default]"
      fi

      if [ -n "$hm" ]; then
        printf '%s%s %s %s%s' "$color" "$sym" "$pct" "$hm" "$reset"
      else
        printf '%s%s %s%s' "$color" "$sym" "$pct" "$reset"
      fi
    '')
    cloc # Count lines of code
    glow # Terminal markdown reader
    ncdu # Disk usage analysis
    tt # Typespeed test
    fastfetch # New neofetch
    cpufetch
    nixfmt # nixvim needs it in PATH: nil_ls formatting + format-on-save
  ];
}
