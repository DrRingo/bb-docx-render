class BbDocxRender < Formula
  desc "Render DOCX templates from Jinja2 data (JSON/YAML/TOML) — standalone binary"
  homepage "https://github.com/DrRingo/bb-docx-render"
  license "Apache-2.0"
  version "1.0.0"

  on_macos do
    on_arm do
      url "https://github.com/DrRingo/bb-docx-render/releases/download/v1.0.0/fill-docx-macos"
      sha256 :no_check
    end
    on_intel do
      url "https://github.com/DrRingo/bb-docx-render/releases/download/v1.0.0/fill-docx-macos"
      sha256 :no_check
    end
  end

  on_linux do
    url "https://github.com/DrRingo/bb-docx-render/releases/download/v1.0.0/fill-docx-linux"
    sha256 :no_check
  end

  def install
    # Binary name from GitHub Release is "fill-docx-macos" / "fill-docx-linux"
    # Rename to the canonical command name "fill-docx"
    downloaded = Dir["fill-docx-*"].first || "fill-docx"
    bin.install downloaded => "fill-docx"
  end

  test do
    output = shell_output("#{bin}/fill-docx --help 2>&1")
    assert_match "fill-docx", output
  end
end
