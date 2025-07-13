{ lib
, rustPlatform
, fetchFromGitHub
}:

rustPlatform.buildRustPackage rec {
  pname = "rudu";
  version = "0.1.3";

  src = fetchFromGitHub {
    owner = "ayungavis";
    repo = "rudu";
    rev = "v0.1.3";
    hash = "sha256-a202cdb9a2317f747c4c157abebff1bb2fd5aafef26758ad1bf148dc4748e548";
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
