{
  description = "Heartstone: a 3D Wheel of Time game (Godot 4)";

  # Pinned to the same nixpkgs revision as the dev desktop so Godot's Vulkan
  # loader matches the Mesa drivers in /run/opengl-driver.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/f4a03c008967841f2a0b3cb7c436fc6fc31671f6";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});
      # Godot needs a writable project dir (.godot cache), so `nix run` copies
      # the store snapshot into the user's cache dir before launching.
      launcher = pkgs: name: args: pkgs.writeShellApplication {
        inherit name;
        runtimeInputs = [ pkgs.godot pkgs.rsync ];
        text = ''
          dir="''${XDG_CACHE_HOME:-$HOME/.cache}/heartstone/project"
          mkdir -p "$dir"
          rsync -a --checksum --delete --chmod=u+w --exclude .godot --exclude renders ${self}/ "$dir/"
          godot --headless --path "$dir" --import >/dev/null 2>&1 || true
          exec godot --path "$dir" ${args} "$@"
        '';
      };
      # The dedicated server: no window, no GPU. Godot needs its import cache beside
      # the project, so the store snapshot is copied into the state directory first.
      mkServer = pkgs: pkgs.writeShellApplication {
        name = "heartstone-server";
        runtimeInputs = [ pkgs.godot pkgs.rsync ];
        text = ''
          state="''${STATE_DIRECTORY:-''${XDG_STATE_HOME:-$HOME/.local/state}/heartstone}"
          mkdir -p "$state/project" "$state/data"
          rsync -a --checksum --delete --chmod=u+w --exclude .godot --exclude renders --exclude dist ${self}/ "$state/project/"
          # Which commit this server is, so a player turned away for a version
          # mismatch can be told which side is out of date.
          printf '{"tag": "", "commit": "%s", "date": %s}\n' "${self.shortRev or self.dirtyShortRev or "dirty"}" "${toString (self.lastModified or 0)}" > "$state/project/build.json"
          # Characters are kept under $state/data and survive updates of the game.
          export XDG_DATA_HOME="$state/data" XDG_CONFIG_HOME="$state/data" XDG_CACHE_HOME="$state/data"
          godot --headless --path "$state/project" --import >/dev/null 2>&1 || true
          exec godot --headless --path "$state/project" -s src/net/server.gd -- "$@"
        '';
      };
    in {
      # services.heartstone: see docs/SERVER.md.
      nixosModules.default = { config, lib, pkgs, ... }:
        let cfg = config.services.heartstone; in {
          options.services.heartstone = {
            enable = lib.mkEnableOption "the Heartstone dedicated server (co-op meeting point and character store)";
            port = lib.mkOption { type = lib.types.port; default = 24690; description = "UDP port players connect to."; };
            openFirewall = lib.mkOption { type = lib.types.bool; default = true; description = "Open the UDP port in the firewall."; };
            environmentFile = lib.mkOption {
              type = lib.types.nullOr lib.types.path; default = null;
              description = "File containing HEARTSTONE_WORD=..., the word players must give to join. Without it anyone who finds the port can play and store characters.";
            };
          };
          config = lib.mkIf cfg.enable {
            networking.firewall.allowedUDPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
            systemd.services.heartstone = {
              description = "Heartstone dedicated server";
              wantedBy = [ "multi-user.target" ];
              after = [ "network.target" ];
              environment.HEARTSTONE_PORT = toString cfg.port;
              serviceConfig = {
                ExecStart = "${mkServer pkgs}/bin/heartstone-server";
                EnvironmentFile = lib.mkIf (cfg.environmentFile != null) cfg.environmentFile;
                DynamicUser = true;
                StateDirectory = "heartstone";
                Environment = [ "HOME=/var/lib/heartstone" ];
                Restart = "on-failure";
                RestartSec = 5;
                # It is a game server reachable from the internet: give it nothing it does not need.
                NoNewPrivileges = true; ProtectSystem = "strict"; ProtectHome = true; PrivateTmp = true; PrivateDevices = true;
                ProtectKernelTunables = true; ProtectKernelModules = true; ProtectControlGroups = true;
                RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
                MemoryMax = "1G";
              };
            };
          };
        };

      # `nix flake check` evaluates the module in a minimal NixOS system.
      checks = forAll (pkgs: {
        module = (nixpkgs.lib.nixosSystem {
          system = pkgs.stdenv.hostPlatform.system;
          modules = [ self.nixosModules.default {
            services.heartstone.enable = true;
            boot.isContainer = true; system.stateVersion = "25.05";
          } ];
        }).config.systemd.units."heartstone.service".unit;
      });

      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            godot
            sway grim            # headless GPU compositor + screenshots
            ffmpeg imagemagick   # frame sequences -> video / contact sheets
            vulkan-tools tmux
          ];
          # tools/export.sh builds dist/ with these (official, generic-Linux templates).
          GODOT_EXPORT_TEMPLATES = "${pkgs.godot.export-templates-bin}/share/godot/export_templates";
        };
      });

      packages = forAll (pkgs: rec {
        default = launcher pkgs "heartstone" "";
        horde = launcher pkgs "heartstone-horde" "res://src/test/test_scene.tscn -- --mode=horde";
        server = mkServer pkgs;
        # A conventional library layout for the exported binary in dist/ (see
        # dist/heartstone). `env` simply runs whatever command follows.
        fhs = pkgs.buildFHSEnv {
          name = "heartstone-fhs";
          targetPkgs = p: with p; [
            vulkan-loader libGL libxkbcommon wayland libdecor alsa-lib libpulseaudio pipewire udev fontconfig dbus
            libx11 libxcursor libxinerama libxext libxrandr libxrender libxi libxfixes
          ];
          runScript = "env";
        };
      });

      apps = forAll (pkgs: {
        default = { type = "app"; program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/heartstone"; };
        horde = { type = "app"; program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.horde}/bin/heartstone-horde"; };
        server = { type = "app"; program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.server}/bin/heartstone-server"; };
        fhs = { type = "app"; program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.fhs}/bin/heartstone-fhs"; };
      });
    };
}
