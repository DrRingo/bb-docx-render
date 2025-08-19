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
      # This wrapper script solves two problems:
      # 1. The `fill_docx.bb` script needs to run from the `libexec` directory
      #    so that `uv` can find the `pyproject.toml` file.
      # 2. User-provided arguments (like `./template.docx`) are relative to the
      #    user's current working directory, not `libexec`.
      #
      # The solution is to convert all arguments that are existing file paths
      # into absolute paths *before* changing the directory.

      args=()
      for arg in "$@"; do
        # Check if the argument is an existing file or directory path
        if [ -e "$arg" ]; then
          # Convert it to an absolute path. `realpath` is standard.
          args+=("$(realpath "$arg")")
        else
          # Otherwise, pass the argument as-is (e.g., flags like -o)
          args+=("$arg")
        fi
      done

      # Now, change to the libexec directory
      cd "#{libexec}"

      # And execute the script with the resolved, absolute paths
      exec "#{Formula["babashka"].opt_bin}/bb" "fill_docx.bb" "${args[@]}"
    EOS
  end

  test do
    assert_match "Cách dùng", shell_output("#{bin}/fill-docx 2>&1", 1)
  end
end
