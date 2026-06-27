{
  description = "Context & Login Manager for OpenBao / Vault";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.stdenvNoCC.mkDerivation rec {
            pname = "baotx";
            version = "1.4.2";

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
    };
}
