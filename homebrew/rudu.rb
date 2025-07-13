class Rudu < Formula
  desc "Fast, parallel Rust CLI tool for analyzing directory sizes"
  homepage "https://github.com/ayungavis/rudu"
  url "https://github.com/ayungavis/rudu/archive/v0.1.8.tar.gz"
  sha256 "8474fce88c6860e48f1d443c727151b89f3d39fe5656ede54ddb632e11c6d09c"
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