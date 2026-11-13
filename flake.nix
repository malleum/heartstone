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
          rsync -a --delete --chmod=u+w --exclude .godot --exclude renders ${self}/ "$dir/"
          exec godot --path "$dir" ${args} "$@"
        '';
      };
    in {
      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            godot
            sway grim            # headless GPU compositor + screenshots
            ffmpeg imagemagick   # frame sequences -> video / contact sheets
            vulkan-tools tmux
          ];
        };
      });

      packages = forAll (pkgs: rec {
        default = launcher pkgs "heartstone" "";
        horde = launcher pkgs "heartstone-horde" "-- --mode=horde";
      });

      apps = forAll (pkgs: {
        default = { type = "app"; program = "${self.packages.${pkgs.system}.default}/bin/heartstone"; };
        horde = { type = "app"; program = "${self.packages.${pkgs.system}.horde}/bin/heartstone-horde"; };
      });
    };
}
