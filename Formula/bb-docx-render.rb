class BbDocxRender < Formula
  desc "Render DOCX templates using Babashka and Python"
  homepage "https://github.com/DrRingo/bb-docx-render"
  url "https://github.com/DrRingo/bb-docx-render/archive/refs/tags/0.1.1.tar.gz"
  sha256 "af9af63214c23a2194de15ce2d830164112c913f9c75825200e2dd412b726fce"
  license "Apache-2.0"

  # uv manages its own Python runtime; babashka is the script runner.
  depends_on "babashka"
  depends_on "uv"

  def install
    # Install all runtime files to libexec.
    # fill_docx.bb uses `--project libexec` so uv finds pyproject.toml here.
    # uv.lock is included so uv can resolve deps from cache without re-solving.
    libexec.install "fill_docx.bb", "render.py", "pyproject.toml", "uv.lock"

    (bin/"fill-docx").write <<~EOS
      #!/bin/bash
      # Wrapper for fill-docx installed via Homebrew.
      #
      # Problem: fill_docx.bb must run from libexec (where pyproject.toml lives),
      # but user-provided paths are relative to the user's cwd.
      # Solution: resolve all user paths to absolute BEFORE cd-ing to libexec.

      set -euo pipefail

      args=()
      original_pwd="$(pwd)"

      while (( "$#" )); do
        case "$1" in
          -o)
            args+=("-o")
            shift
            # Output path may not exist yet — can't use realpath.
            # If relative, prepend original pwd.
            if [[ "$1" != /* && "$1" != ~* ]]; then
              args+=("${original_pwd}/$1")
            else
              args+=("$1")
            fi
            shift
            ;;
          *)
            # Input path must exist — use realpath with -- to handle paths
            # that might start with a dash.
            args+=("$(realpath -- "$1")")
            shift
            ;;
        esac
      done

      cd "#{libexec}"
      exec "#{Formula["babashka"].opt_bin}/bb" "fill_docx.bb" "${args[@]}"
    EOS
  end

  test do
    # Verify the wrapper runs and prints usage (exit 1 = expected with no args).
    # Using ASCII-safe pattern that appears in the usage output.
    output = shell_output("#{bin}/fill-docx 2>&1", 1)
    assert_match "fill_docx.bb", output
  end
end
