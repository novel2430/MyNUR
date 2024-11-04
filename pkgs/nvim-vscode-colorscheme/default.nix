{pkgs, ...}:

with pkgs;
vimUtils.buildVimPlugin {
  name = "vscode-nvim";
  src = builtins.fetchGit {
    url = "https://github.com/Mofiqul/vscode.nvim.git";
    ref = "main";
    rev = "7de58b7a6d55fe48475d0ba2fddbcec871717761";
  };
}
