{pkgs, ...}:

with pkgs;
vimUtils.buildVimPlugin {
  name = "vscode-nvim";
  src = builtins.fetchGit {
    url = "https://github.com/novel2430/vscode.nvim.git";
    ref = "main";
    rev = "1b4d5dc51539f0ade4bb1ffc1fbae41b5f8846ec";
  };
}
