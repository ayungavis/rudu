{ lib
, rustPlatform
, fetchFromGitHub
}:

rustPlatform.buildRustPackage rec {
  pname = "rudu";
  version = "0.2.4";

  src = fetchFromGitHub {
    owner = "ayungavis";
    repo = "rudu";
    rev = "v0.2.4";
    hash = "sha256-34f86737d527aaf77e3b3892de2690435e53bd84a80719e7fd43c039bfaed94b";
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
