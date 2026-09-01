{ inputs }:

[
  (final: prev:
    let
      unstable = inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system};
    in {
      vimPlugins = unstable.vimPlugins;
      bun = unstable.bun;
      d2 = unstable.d2;
      helm-ls = unstable.helm-ls;
      uv = unstable.uv;
    })

  (final: prev: {
    direnv =
      if prev.stdenv.isDarwin then
        prev.direnv.overrideAttrs (_old: {
          doCheck = false;
          doInstallCheck = false;
        })
      else
        prev.direnv;
  })
]
