{ config, pkgs, unstable, ... }:

{
  # Qwen 3.5 9B CUDA
  services.ollama = {
    enable = true;
    acceleration = "cuda";
    package = unstable.ollama-cuda;
    loadModels = [ "qwen3.5:9b" ];
  };
  # preloading is a bit hacky, but once this issue is resolved we can replace it https://github.com/ollama/ollama/pull/16207
  systemd.services.ollama.environment = {
    OLLAMA_KEEP_ALIVE = "-1";
    OLLAMA_CUDA = "1";
  };
  systemd.services.ollama.serviceConfig.ExecStartPost = "/bin/sh -c 'sleep 5; ${config.services.ollama.package}/bin/ollama run ${builtins.head config.services.ollama.loadModels} \"\" > /dev/null 2>&1 &'";

  environment.systemPackages = with pkgs; [ 
    unstable.ollama-cuda 
  ];
}
