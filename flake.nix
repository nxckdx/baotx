{
  description = "Context & Login Manager for OpenBao / Vault";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      # Read from ./VERSION so the release-please bump (which already targets this
      # file) doesn't also need to touch flake.nix/default.nix by hand.
      version = nixpkgs.lib.removeSuffix "\n" (builtins.readFile ./VERSION);
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "baotx";
            inherit version;

            src = ./.;

            nativeBuildInputs = [ pkgs.makeWrapper ];

            installPhase = ''
              mkdir -p $out/bin
              cp baotx $out/bin/baotx
              chmod +x $out/bin/baotx
              
              wrapProgram $out/bin/baotx \
                --prefix PATH : ${pkgs.lib.makeBinPath [
                  pkgs.bash
                  pkgs.curl
                  pkgs.jq
                  pkgs.yq-go
                  pkgs.fzf
                  pkgs.libsecret
                ]}
            '';

            meta = with pkgs.lib; {
              description = "Context & Login Manager for OpenBao / Vault";
              homepage = "https://github.com/nxckdx/baotx";
              license = licenses.mit;
              mainProgram = "baotx";
              platforms = platforms.all;
            };
          };
        });

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              bash
              curl
              jq
              yq-go
              fzf
              libsecret
            ];
          };
        });

      # Installing the package alone is not enough for `token_storage: "keyring"`
      # (the default) to work: `secret-tool` needs a running Secret Service
      # provider. NixOS does not enable one by default outside of a full GNOME
      # desktop, so this module wires up gnome-keyring for you.
      nixosModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.baotx;
        in
        {
          options.programs.baotx.enable = lib.mkEnableOption "BaoTx, the context and login manager for OpenBao/Vault";

          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.default ];
            services.gnome.gnome-keyring.enable = true;
          };
        };
    };
}
