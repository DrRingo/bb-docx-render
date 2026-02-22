class BbDocxRender < Formula
  desc "Render DOCX templates using Babashka and Python"
  homepage "https://github.com/DrRingo/bb-docx-render"
  url "https://github.com/DrRingo/bb-docx-render/archive/refs/tags/0.1.5.tar.gz"
  sha256 "7285f0f4246a2b8cdd81a326e1bad8dc25541662f934ca4cd8aae346261020bc"
  license "Apache-2.0"

  depends_on "babashka"
  depends_on "uv"

  def install
    # Copy all runtime files to libexec (writable during install).
    libexec.install "fill_docx.bb", "render.py", "pyproject.toml", "uv.lock"

    # Pre-install Python deps into libexec/.venv while the Cellar is still
    # writable. At runtime the Cellar is read-only, so uv must NOT try to
    # create or modify the venv then — we point it at this pre-built venv via
    # UV_PROJECT_ENVIRONMENT in the wrapper below.
    system Formula["uv"].opt_bin/"uv", "sync",
           "--project", libexec,
           "--python-preference", "only-system"

    (bin/"fill-docx").write <<~EOS
      #!/bin/bash
      # Wrapper for fill-docx installed via Homebrew.
      #
      # Problem: fill_docx.bb must run from libexec (where pyproject.toml/venv
      # live), but user-provided paths are relative to the user's cwd.
      # Solution: resolve all user paths to absolute BEFORE cd-ing to libexec.
      # When no -o is given, default output is placed in the user's cwd.
      #
      # UV_PROJECT_ENVIRONMENT tells uv to reuse the pre-built venv inside
      # libexec without attempting any writes (Cellar is read-only at runtime).

      set -euo pipefail

      export UV_PROJECT_ENVIRONMENT="#{libexec}/.venv"

      args=()
      has_output=false
      original_pwd="$(pwd)"

      while (( "$#" )); do
        case "$1" in
          -o)
            args+=("-o")
            has_output=true
            shift
            # Output path may not exist yet — can't use realpath.
            if [[ "$1" != /* && "$1" != ~* ]]; then
              args+=("${original_pwd}/$1")
            else
              args+=("$1")
            fi
            shift
            ;;
          *)
            args+=("$(realpath -- "$1")")
            shift
            ;;
        esac
      done

      # Default output goes to user's cwd, not libexec.
      if [[ "$has_output" == false ]]; then
        args+=("-o" "${original_pwd}/output.docx")
      fi

      cd "#{libexec}"
      exec "#{Formula["babashka"].opt_bin}/bb" "fill_docx.bb" "${args[@]}"
    EOS
  end

  test do
    output = shell_output("#{bin}/fill-docx 2>&1", 1)
    assert_match "fill_docx.bb", output
  end
end
