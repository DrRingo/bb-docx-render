class BbDocxRender < Formula
  desc "Render DOCX templates using Babashka and Python"
  homepage "https://github.com/DrRingo/bb-docx-render"
  url "https://github.com/DrRingo/bb-docx-render/archive/refs/tags/0.1.1.tar.gz"
  sha256 "af9af63214c23a2194de15ce2d830164112c913f9c75825200e2dd412b726fce"
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

      # Make all input paths absolute. The output path is special.
      # The script itself will be run from libexec.
      # All user-provided paths must be absolute.
      while (( "$#" )); do
        case "$1" in
          -o)
            args+=("-o")
            shift
            # The output path may not exist yet, so we can't use realpath.
            # If it's not absolute, prepend the original pwd.
            if [[ "$1" != /* && "$1" != ~* ]]; then
              args+=("/${original_pwd}/$1")
            else
              args+=("$1")
            fi
            shift
            ;;
          *)
            # This is an input path. It must exist. Use realpath.
            args+=("$(realpath "$1")")
            shift
            ;;
        esac
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
