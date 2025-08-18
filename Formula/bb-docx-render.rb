class BbDocxRender < Formula
  include Language::Python::Virtualenv

  desc "Render DOCX templates using Babashka and Python"
  homepage "https://github.com/example/bb-docx-render"
  url "https://github.com/DrRingo/bb-docx-render/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "d0550113aa5f2c3cb7f4a9dccd4936d67d455a60f3d543e1c96b795db8549b23"
  license "Apache-2.0"

  depends_on "babashka"
  depends_on "python@3.11"

  resource "docxtpl" do
    url "https://files.pythonhosted.org/packages/8c/3a/de0754ed1bcc47210307b7a98708d71207eb3f52594e2cf23a1ae97d7f08/docxtpl-0.20.1.tar.gz"
    sha256 "5bab05a2c60b225c730ce18e9e2d40d748b4a12f599e150badbcb659088a51d4"
  end

  resource "jinja2" do
    url "https://files.pythonhosted.org/packages/df/bf/f7da0350254c0ed7c72f3e33cef02e048281fec7ecec5f032d4aac52226b/jinja2-3.1.6.tar.gz"
    sha256 "0137fb05990d35f1275a587e9aee6d56da821fc83491a0fb838183be43f66d6d"
  end

  resource "python-docx" do
    url "https://files.pythonhosted.org/packages/a9/f7/eddfe33871520adab45aaa1a71f0402a2252050c14c7e3009446c8f4701c/python_docx-1.2.0.tar.gz"
    sha256 "7bc9d7b7d8a69c9c02ca09216118c86552704edc23bac179283f2e38f86220ce"
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
