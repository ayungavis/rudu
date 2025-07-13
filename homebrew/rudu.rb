class Rudu < Formula
  desc "Fast, parallel Rust CLI tool for analyzing directory sizes"
  homepage "https://github.com/ayungavis/rudu"
  url "https://github.com/ayungavis/rudu/archive/v0.2.5.tar.gz"
  sha256 "e9df1383d177a5e28ce1151b12dde23d6714c3a7fcc22614f3101077bb1dc7cc"
  license "MIT"
  head "https://github.com/ayungavis/rudu.git", branch: "main"

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
  end

  test do
    # Test that the binary runs and shows help
    assert_match "Fast, parallel Rust CLI tool for analyzing directory sizes", shell_output("#{bin}/rudu --help")
    
    # Test basic functionality on a temporary directory
    system "mkdir", "-p", "test_dir/subdir"
    system "echo", "test content", ">", "test_dir/file.txt"
    system "echo", "more content", ">", "test_dir/subdir/file2.txt"
    
    output = shell_output("#{bin}/rudu test_dir")
    assert_match "test_dir", output
    
    # Clean up
    system "rm", "-rf", "test_dir"
  end
end 