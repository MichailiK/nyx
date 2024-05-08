{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;

  cfg = config.modules.system.sound;
  dev = config.modules.device;
in {
  config = mkIf (cfg.enable && dev.hasSound) {
    # Enable the threadirqs kernel parameter to reduce audio latency
    # See <https://github.com/musnix/musnix/blob/master/modules/base.nix#L56>
    boot.kernelParams = ["threadirqs"];

    # port of https://gitlab.archlinux.org/archlinux/packaging/packages/realtime-privileges
    # see https://wiki.archlinux.org/title/Realtime_process_management
    # tldr: realtime processes have higher priority than normal processes
    # and that's a good thing
    users = {
      users."${config.modules.system.mainUser}".extraGroups = ["realtime"];
      groups.realtime = {};
    };

    security.pam.loginLimits = [
      {
        domain = "@realtime";
        type = "-";
        item = "rtprio";
        value = 99;
      }
      {
        domain = "@realtime";
        type = "-";
        item = "memlock";
        value = "unlimited";
      }
      {
        domain = "@realtime";
        type = "-";
        item = "nice";
        value = -11;
      }
      {
        domain = "@realtime";
        item = "nofile";
        type = "soft";
        value = "99999";
      }
      {
        domain = "@realtime";
        item = "nofile";
        type = "hard";
        value = "524288";
      }
    ];

    services = {
      # configure PipeWire for low latency
      # the below configuration may not fit every use case
      # and you are recommended to experiment with the values
      # in order to find the perfect configuration
      pipewire = let
        # Higher audio rate equals less latency always, unless you
        # increase your quantum.
        # To calculate node latency for your audio device take the
        # quantum size divided by your audio rate
        # => 64/96000 = 0.00066666666 * 1000 = 0.6ms # this is 0.6ms node latency
        # To check client latency use `pw-top`, take the quantum size
        # and the audio rate of the client then use `quantum / audio rate * 1000`
        # to get overall latency for the client
        quantum = toString 64;
        rate = toString 48000;
        qr = "${quantum}/${rate}"; # 64/48000
      in {
        # Additional configuration files that will be placed in /etc/pipewire/pipewire.conf.d/
        # with the given file name. According to the documentation, those files take JSON therefore
        # nixpkgs' toJSON should be suitable to write the configuration files via Nix expressions.
        # P.S. Using extraConfig already converts the expression to JSON, so toJSON is not necessary
        # Also see: <https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Config-PipeWire#quantum-ranges>
        # Useful commands:
        #  pw-top                                            # see live stats
        #  journalctl -b0 --user -u pipewire                 # see logs (spa resync in "bad")
        #  pw-metadata -n settings 0                         # see current quantums
        #  pw-metadata -n settings 0 clock.force-quantum 128 # override quantum
        #  pw-metadata -n settings 0 clock.force-quantum 0   # disable override
        extraConfig = {
          pipewire."92-low-latency" = {
            "context.properties" = {
              "default.clock.rate" = rate;
              "default.clock.quantum" = quantum;
              "default.clock.min-quantum" = quantum;
              "default.clock.max-quantum" = quantum;
              "default.clock.allowed-rates" = [rate];
            };

            "context.modules" = [
              {
                name = "libpipewire-module-rtkit";
                flags = ["ifexists" "nofail"];
                args = {
                  "nice.level" = -15;
                  "rt.prio" = 88;
                  "rt.time.soft" = 200000;
                  "rt.time.hard" = 200000;
                };
              }
              {
                name = "libpipewire-module-protocol-pulse";
                args = {
                  "server.address" = ["unix:native"];
                  "pulse.min.quantum" = qr;
                  "pulse.min.req" = qr;
                  "pulse.min.frag" = qr;
                };
              }
            ];

            "stream.properties" = {
              "node.latency" = qr;
              "resample.quality" = 1;
            };
          };

          pipewire-pulse."92-low-latency" = {
            "context.modules" = [
              {
                name = "libpipewire-module-protocol-pulse";
                args = {
                  "pulse.min.req" = qr;
                  "pulse.default.req" = qr;
                  "pulse.max.req" = qr;
                  "pulse.min.quantum" = qr;
                  "pulse.max.quantum" = qr;
                };
              }
            ];

            "stream.properties" = {
              "node.latency" = qr;
              "resample.quality" = 1;
            };
          };
        };

        wireplumber = {
          enable = true;
          extraConfig = mkMerge [
            {
              # Tell wireplumber to be more verbose
              "log-level-debug" = {
                "context.properties" = {
                  "log.level" = "D"; # output debug logs
                };
              };

              # Configure each device/card/output to use the low latency configuration
              "92-low-latency" = {
                # Some applications still use the alsa channels, so the configuration
                # for Wireplumber doesn't properly apply to them. In that case, they should
                # follow the ALSA configuration instead.
                "monitor.alsa.rules" = [
                  {
                    matches = [
                      # Matches all sinks.
                      {node.name = "~alsa_output.*";}
                    ];

                    actions.update-props = {
                      # Give a human-readable name to the matching devices/sources/sinks.
                      "node.nick" = "ALSA Low Latency";

                      # Low latency configuration
                      "audio.rate" = rate;
                      "audio.format" = "S32LE";
                      "resample.quality" = 4;
                      "resample.disable" = false;
                      "session.suspend-timeout-seconds" = 0;
                      "api.alsa.period-size" = 2;
                      # Default: 0
                      "api.alsa.headroom" = 128;
                      # Default: 2
                      "api.alsa.period-num" = 2;
                      ## generally, USB soundcards use the batch mode
                      "api.alsa.disable-batch" = false;
                    };
                  }
                ];
              };
            }

            (mkIf dev.hasBluetooth {
              bluetooth."10-bluez" = {
                "monitor.bluez.rules" = [
                  {
                    matches = [{"device.name" = "~bluez_card.*";}];
                    actions = {
                      update-props = {
                        "bluez5.roles" = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]";
                        # Set quality to high quality instead of the default of auto
                        "bluez5.a2dp.ldac.quality" = "hq";
                        "bluez5.enable-msbc" = true;
                        "bluez5.enable-sbc-xq" = true;
                        "bluez5.enable-hw-volume" = true;
                      };
                    };
                  }
                ];
              };
            })
          ];
        };
      };

      udev.extraRules = ''
        KERNEL=="cpu_dma_latency", GROUP="realtime"
        KERNEL=="rtc0", GROUP="realtime"
        KERNEL=="hpet", GROUP="realtime"
      '';
    };
  };
}
