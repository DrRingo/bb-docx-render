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
      # This is the definitive wrapper script.
      # Problem: The `fill_docx.bb` script (from the source tarball) must run from
      # `libexec` for `uv` to work, but all user-provided paths are relative to `pwd`.
      # Solution: Make ALL paths absolute before changing directory.

      args=()
      next_is_output=false
      original_pwd="$(pwd)"

      for arg in "$@"; do
        if [ "$next_is_output" = true ]; then
          # This is the output path. It may not exist yet.
          # If it's not already absolute, prepend the original pwd.
          if [[ "$arg" != /* ]]; then
            args+=("${original_pwd}/${arg}")
          else
            args+=("$arg")
          fi
          next_is_output=false
        elif [ "$arg" = "-o" ]; then
          args+=("-o")
          next_is_output=true
        elif [ -e "$arg" ]; then
          # This is an existing input path. Use realpath to make it absolute.
          args+=("$(realpath "$arg")")
        else
          # Any other argument (e.g., a Jinja template string for the output name)
          args+=("$arg")
        fi
      done

      # Now, change to the libexec directory
      cd "#{libexec}"

      # And execute the script with the fully resolved, absolute paths
      exec "#{Formula["babashka"].opt_bin}/bb" "fill_docx.bb" "${args[@]}"
    EOS
  end

  test do
    assert_match "Cách dùng", shell_output("#{bin}/fill-docx 2>&1", 1)
  end
end
