{ config, pkgs, lib, ... }: with lib; let
  inherit (import ../lib/run.nix { inherit pkgs; }) nixRunWrapper;
  cfg = config.runners;
  runType = types.submodule ({ config, name, ... }: {
    options = {
      name = mkOption {
        type = types.str;
        default = name;
      };
      executable = mkOption {
        type = types.str;
        default = name;
      };
      command = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      package = mkOption {
        type = types.package;
      };
      runner = mkOption {
        type = types.package;
      };
      set = mkOption {
        type = types.unspecified;
        readOnly = true;
      };
    };
    config = {
      runner = mkOptionDefault (nixRunWrapper config.executable config.package);
      package = mkOptionDefault (pkgs.writeShellScriptBin config.executable config.command);
      set = {
        inherit (config) package executable name;
      };
    };
  });
  lazyRunType = types.submodule ({ config, name, ... }: {
    options = {
      nixRun = mkOption {
        type = types.listOf types.str;
        default = [ "nix" "run" ];
      };
      name = mkOption {
        type = types.str;
        default = name;
      };
      executable = mkOption {
        type = types.str;
        default = name;
      };
      file = mkOption {
        type = types.nullOr types.path;
        default = null;
      };
      attr = mkOption {
        type = types.str;
      };
      args = mkOption {
        type = types.listOf types.str;
      };
      set = mkOption {
        type = types.unspecified;
        readOnly = true;
      };
      out = {
        runArgs = mkOption {
          type = types.listOf types.str;
          readOnly = true;
        };
      };
    };
    config = {
      args = mkIf (config.file != null) [ "-f" (toString config.file) ];
      out = {
        runArgs = config.nixRun ++ config.args ++ [ config.attr "-c" config.executable ];
      };
      set = {
        inherit (config) attr file executable name;
      };
    };
  });
in {
  options = {
    runners = {
      lazy = {
        file = mkOption {
          type = types.nullOr types.path;
          default = null;
        };
        attrPrefix = mkOption {
          type = types.str;
          default = "runners.run.";
        };
        args = mkOption {
          type = types.listOf types.str;
          default = [ ];
        };
        run = mkOption {
          type = types.attrsOf lazyRunType;
        };
        nativeBuildInputs = mkOption {
          type = types.listOf types.package;
          readOnly = true;
        };
      };
      run = mkOption {
        type = types.attrsOf runType;
        default = { };
      };
    };
    run = mkOption {
      type = types.attrsOf types.unspecified;
    };
  };

  config = {
    runners.lazy = {
      run = mapAttrs' (k: run: nameValuePair k (mapAttrs (_: mkDefault) {
        attr = "${cfg.lazy.attrPrefix}${k}.package";
        inherit (cfg.lazy) args file;
        inherit (run) executable name;
      })) cfg.run;
      nativeBuildInputs = mapAttrsToList (k: v: pkgs.writeShellScriptBin v.name ''
        exec ${escapeShellArgs v.out.runArgs} "$@"
      '') cfg.lazy.run;
    };
    run = mapAttrs (_: r: r.runner) cfg.run;
  };
}
