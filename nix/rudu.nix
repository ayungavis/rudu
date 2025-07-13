{ lib
, rustPlatform
, fetchFromGitHub
}:

rustPlatform.buildRustPackage rec {
  pname = "rudu";
  version = "0.2.1";

  src = fetchFromGitHub {
    owner = "ayungavis";
    repo = "rudu";
    rev = "v0.2.1";
    hash = "sha256-19f57e89a175062213eb3af37cadc9d7d06f6980491d04f628881fe1eaf243be";
  };

  cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  meta = with lib; {
    description = "Fast, parallel Rust CLI tool for analyzing directory sizes";
    homepage = "https://github.com/ayungavis/rudu";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    mainProgram = "rudu";
  };
}
