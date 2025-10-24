{
  description = "Development environment for blink-cmp-skkeleton";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Neovim
            neovim

            # Lua tools
            stylua
            selene

            # Git and GitHub CLI
            git
            gh
          ];

          shellHook = ''
            echo "blink-cmp-skkeleton development environment"
            echo "Available tools:"
            echo "  - neovim: $(nvim --version | head -n1)"
            echo "  - stylua: $(stylua --version)"
            echo "  - selene: $(selene --version)"
            echo ""
            echo "Run tests: nvim --headless -u tests/minimal_init.lua -c 'PlenaryBustedDirectory tests/' -c 'qa'"
            echo "Format code: stylua ."
            echo "Lint code: selene ."
          '';
        };
      }
    );
}
