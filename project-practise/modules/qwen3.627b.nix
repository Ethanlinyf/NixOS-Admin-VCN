{ config, pkgs, unstable, ... }:

{
  # Qwen 3.6 27B CUDA
  services.ollama = {
    enable = true;
    acceleration = "cuda";
    package = unstable.ollama; #ollama-cuda;
    loadModels = [ "qwen3.6:27b" ];
  };
  # keep ollama in memory for responsiveness
  systemd.services.ollama.environment = {
    OLLAMA_KEEP_ALIVE = "-1";
    OLLAMA_CUDA = "1";
  };
  systemd.services.ollama.serviceConfig.ExecStartPost = "/bin/sh -c 'sleep 5; ${config.services.ollama.package}/bin/ollama run ${builtins.head config.services.ollama.loadModels} \"\" > /dev/null 2>&1 &'";

  environment.systemPackages = with pkgs; [ 
    unstable.ollama-cuda 
  ];
}