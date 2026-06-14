let upstream-ps =
      https://github.com/purescript/package-sets/releases/download/psc-0.15.15-20240320/packages.dhall
        sha256:ae8a25645e81ff979beb397a21e5d272fae7c9ebdb021a96b1b431388c8f3c34

let upstream-lua =
      https://github.com/purescript-lua/purescript-lua-package-sets/releases/download/psc-0.15.15-20240341/packages.dhall
        sha256:8c5adf1e1e686580b132974ebf9691c5237389ff81791614c6f3837568d8e823

in  upstream-ps // upstream-lua
