class BbDocxRender < Formula
  include Language::Python::Virtualenv

  desc "Render DOCX templates using Babashka and Python"
  homepage "https://github.com/example/bb-docx-render"
  url "https://github.com/example/bb-docx-render/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "d0550113aa5f2c3cb7f4a9dccd4936d67d455a60f3d543e1c96b795db8549b23"
  license "Apache-2.0"

  depends_on "babashka"
  depends_on "python@3.11"

  resource "docxtpl" do
    url "https://files.pythonhosted.org/packages/TODO/docxtpl-0.16.7.tar.gz"
    sha256 "TODO"
  end

  resource "jinja2" do
    url "https://files.pythonhosted.org/packages/TODO/Jinja2-3.1.3.tar.gz"
    sha256 "TODO"
  end

  resource "python-docx" do
    url "https://files.pythonhosted.org/packages/TODO/python-docx-0.8.11.tar.gz"
    sha256 "TODO"
  end

  def install
    virtualenv_install_with_resources
    libexec.install "fill_docx.bb"
    (bin/"fill-docx").write_env_script libexec/"fill_docx.bb",
      PATH: "#{libexec}/bin:$PATH"
  end

  test do
    assert_match "Cách dùng", shell_output("#{bin}/fill-docx 2>&1", 1)
  end
end
