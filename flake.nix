{
  outputs = { self, nixpkgs }:
  let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
      overlays = [ self.overlay ];
      config.allowUnfree = true;
      config.cudaSupport = true;
    };
  in
  {
    devShells.x86_64-linux.default =  pkgs.python3Packages.dev-triton.overridePythonAttrs (attrs: {
      nativeBuildInputs = attrs.nativeBuildInputs ++ [
        pkgs.python3Packages.venvShellHook
        pkgs.dev-torch
      ];
      shellHook =  ''
        export TRITON_HOME="$PWD"/.triton
        export MAX_JOBS="$NIX_BUILD_CORES"
        export TRITON_LIBCUDA_PATH=/run/opengl-driver/lib

        # Fix the cuda include paths
        export TRITON_CUDART_PATH="$TRITON_CUDART_PATH/include"

        # Can't figure out how to set up clang stdenv
        # export TRITON_BUILD_WITH_CLANG_LLD=TRUE
        runHook venvShellHook
        . ./.venv/bin/activate
      '';
      venvDir = "./.venv";
      postVenvCreation = ''
        pip install -e python --no-build-isolation
      '';
    });

    packages.x86_64-linux = {
      triton-llvm = pkgs.dev-triton-llvm;
      trition = pkgs.python3Packages.dev-triton;
      inherit (pkgs) python3 python3Packages;
    };

    overlay = final: prev: {
      python3 =
        let myPython =
          prev.python3.override {
            self = myPython;
            packageOverrides = pyfinal: pyprev: {
              dev-triton = (pyfinal.triton.override {
                llvm = final.dev-triton-llvm;
                cudaSupport = true;
              }).overridePythonAttrs (attrs: {
                dependencies = attrs.dependencies ++ [
                  pyfinal.pybind11
                  pyfinal.wheel
                  final.ninja
                  final.cmake
                ];

                LLVM_SYSPATH = "${final.dev-triton-llvm.out}/lib/cmake/llvm";
                LLVM_INCLUDE_DIRS = "${final.dev-triton-llvm.out}/include";
                LLVM_LIBRARY_DIR = "${final.dev-triton-llvm.out}/lib";
              });
            };
          };
        in myPython;
      python3Packages = final.lib.attrsets.recurseIntoAttrs final.python3.pkgs;
      dev-torch = (final.python3Packages.torch-bin.override { triton = null; }).overridePythonAttrs (attrs: {
        dependencies = final.lib.lists.remove final.python3Packages.triton attrs.dependencies;
      });
      dev-openai-triton-llvm = final.dev-triton-llvm;
      dev-triton-llvm = final.triton-llvm.overrideAttrs ({
        version = "llvmorg-21-init";
        patches = [];
        src = final.fetchFromGitHub {
          owner = "llvm";
          repo = "llvm-project";
          rev = "1188b1ff7b956cb65d8ddda5f1e56c432f1a57c7";
          hash = "sha256-iwG0bWnrVX9xbHB4eIe/JxQNFdDHb/COXo4d0joOlDE=";
        };
      });
    };
  };
}
