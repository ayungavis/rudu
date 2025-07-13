{ lib
, rustPlatform
, fetchFromGitHub
}:

rustPlatform.buildRustPackage rec {
  pname = "rudu";
  version = "0.2.2";

  src = fetchFromGitHub {
    owner = "ayungavis";
    repo = "rudu";
    rev = "v0.2.2";
    hash = "sha256-7f2e6497acfdb882fb7bbeb50f234c557737e943672bd366bd8c1643074de77e";
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
