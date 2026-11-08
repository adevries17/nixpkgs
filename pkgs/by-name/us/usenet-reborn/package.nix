{
  pkgs,
  lib,
  fetchFromSourcehut,
  rustPlatform,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "usenet-reborn";
  version = "1.1.0";

  nativeBuildInputs = with pkgs; [
    pkg-config
  ];

  buildInputs = with pkgs; [
    openssl
    sqlite
  ];

  src = fetchFromSourcehut {
    owner = "~rek2";
    repo = "usenet_reborn";
    tag = finalAttrs.version;
    vc = "git";
    fetchSubmodules = false;
    hash = "sha256-WyGpGcEVcF10dedH9snVE3c8DsKIQkPwJ8EBWT8eooQ=";
  };

  cargoHash = "sha256-2PEOvFwlVe0J3m0V7rRuFnEsQDE0OZ6A/qauPzpAa4o=";

  meta = {
    description = "The TUI client for Usenet enthusiasts";
    license = lib.licenses.gpl3;
    maintainers = with lib.maintainers; [
      adevries17
    ];
  };
})
