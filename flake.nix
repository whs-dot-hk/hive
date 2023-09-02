# SPDX-FileCopyrightText: 2022 The Standard Authors
#
# SPDX-License-Identifier: Unlicense
{
  description = "The Hive - The secretly open NixOS-Society";

  inputs.paisano = {
    url = "github:divnix/paisano";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # override downstream with inputs.hive.inputs.nixpkgs.follows = ...
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

  inputs = {
    colmena.url = "github:divnix/blank";
    disko.url = "github:divnix/blank";
    nixos-generators.url = "github:divnix/blank";
    home-manager.url = "github:divnix/blank";
    haumea.url = "github:nix-community/haumea?ref=v0.2.1";
    haumea.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: let
    hive = haumea.lib.load {
      src = ./src;
      loader = haumea.lib.loaders.scoped;
      inputs = removeAttrs (inputs // {inherit inputs;}) ["self"];
    };

    # compat wrapper for haumea.lib.load
    inherit (inputs) haumea;
    inherit (inputs.nixpkgs) lib;
    load = {
      inputs,
      cell,
      src,
    }:
    # modules/profiles are always functions
    {
      config,
      lib,
      options,
      pkgs,
      ...
    }: let
      cr = cell.__cr ++ [(baseNameOf src)];
      file = "${inputs.self.outPath}#${lib.concatStringsSep "/" cr}";

      defaultWith = import (haumea + /src/loaders/__defaultWith.nix) {inherit lib;};
      inputs' = {inherit inputs cell config lib options pkgs;};
      loader = defaultWith (scopedImport inputs') inputs';
    in
      if lib.pathIsDirectory src
      then
        lib.setDefaultModuleLocation file (haumea.lib.load {
          inherit src;
          loader = haumea.lib.loaders.scoped;
          transformer = with haumea.lib.transformers; [
            (hoistLists "_imports" "imports")
            liftDefault
          ];
          inputs = inputs';
        })
      # Mimic haumea for a regular file
      else lib.setDefaultModuleLocation file (loader src);

    findLoad = {
      inputs,
      cell,
      block,
    }:
      with builtins;
        lib.mapAttrs'
        (n: _:
          lib.nameValuePair
          (lib.removeSuffix ".nix" n)
          (load {
            inherit inputs cell;
            src = block + /${n};
          }))
        (removeAttrs (readDir block) ["default.nix"]);
  in
    haumea.lib
    // {
      inherit load findLoad;
      inherit (hive) blockTypes collect;
      inherit (inputs.paisano) grow growOn pick harvest winnow;
    };
}
