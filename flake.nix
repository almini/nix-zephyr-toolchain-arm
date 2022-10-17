{
  description = "Zephyr ARM Toolchain";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  outputs = {self, nixpkgs}: 
    let 

      supportedSystems = ["x86_64-linux" "aarch64-linux"];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });

    in {

      packages = forAllSystems (system:
        let pkgs = nixpkgsFor.${system};
        in rec {

          zephyr-toolchain-arm = with pkgs; stdenv.mkDerivation rec {
            pname = "zephyr-toolchain-arm";
            version = "0.15.1";

            platform = {
              aarch64-linux = "linux-aarch64";
              x86_64-linux = "linux-x86_64";
            }.${system} or (throw "Unsupported system: ${system}");

            src = fetchurl {
              url = "https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${version}/toolchain_${platform}_arm-zephyr-eabi.tar.gz";
              sha256 = {
                aarch64-linux = "0b95p5gylh7s79m7kwksv6fkbyb00ial0ljqwmf385yfra6il19d";
                x86_64-linux = "1jdzbnwr0wzrasyi8wbl9q2hz3qrprnq6zn0i55zqnymi57b2p2m";
              }.${system} or (throw "Unsupported system: ${system}");
            };

            dontConfigure = true;
            dontBuild = true;
            dontPatchELF = true;
            dontStrip = true;

            installPhase = ''
              mkdir -p $out
              cp -r * $out
            '';

            preFixup = ''
              find $out -type f | while read f; do
                patchelf "$f" > /dev/null 2>&1 || continue
                patchelf --set-interpreter $(cat ${stdenv.cc}/nix-support/dynamic-linker) "$f" || true
                patchelf --set-rpath ${lib.makeLibraryPath [ "$out" stdenv.cc.cc ncurses5 python38 ]} "$f" || true
              done
            '';

            meta = with lib; {
              homepage = "https://www.zephyrproject.org/";
              description = "Pe-built GNU toolchain for ARM Cortex-M processors for the Zephyr RTOS";
              platforms = [ "x86_64-linux" "aarch64-linux" ];
            };
          };

          default = zephyr-toolchain-arm;

        });

    };

}