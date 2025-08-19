class BbDocxRender < Formula
  desc "Render DOCX templates using Babashka and Python"
  homepage "https://github.com/DrRingo/bb-docx-render"
  url "https://github.com/DrRingo/bb-docx-render/archive/refs/tags/0.1.tar.gz"
  sha256 "506b290ca38613d505010abcc945e270f6a30cfb8d555ee99aef204f4f7e78c4"
  license "Apache-2.0"

  depends_on "babashka"
  depends_on "uv"

  def install
    # The script uses `uv` to manage its own Python environment based on pyproject.toml,
    # so we don't need to create a virtualenv with resources manually.
    # We just need to install the script and its config, then create a wrapper.
    libexec.install "fill_docx.bb", "pyproject.toml"
    (bin/"fill-docx").write <<~EOS
      #!/bin/bash
      # Change to the script's directory so `uv` can find pyproject.toml
      cd "#{libexec}"
      exec "#{Formula["babashka"].opt_bin}/bb" "fill_docx.bb" "$@"
    EOS
  end

  test do
    assert_match "Cách dùng", shell_output("#{bin}/fill-docx 2>&1", 1)
  end
end
