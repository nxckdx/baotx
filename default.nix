{ pkgs ? import <nixpkgs> {} }:

pkgs.stdenvNoCC.mkDerivation rec {
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
}
