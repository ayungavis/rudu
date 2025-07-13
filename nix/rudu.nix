{ lib
, rustPlatform
, fetchFromGitHub
}:

rustPlatform.buildRustPackage rec {
  pname = "rudu";
  version = "0.1.5";

  src = fetchFromGitHub {
    owner = "ayungavis";
    repo = "rudu";
    rev = "v0.1.5";
    hash = "sha256-f3c9ca1a250c61cec9a8b9a99b9561c48a080efe2ca7649ccb42d106bfa720f1";
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
