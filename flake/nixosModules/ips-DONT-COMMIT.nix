let
  all = {
    mainnet1-rel-au-1 = {
      privateIpv4 = "172.31.34.188";
      publicIpv4 = "54.206.198.244";
      publicIpv6 = "2406:da1c:eb9:9500:b460:a462:9ab9:b119";
    };

    mainnet1-rel-br-1 = {
      privateIpv4 = "172.31.28.207";
      publicIpv4 = "54.232.83.45";
      publicIpv6 = "2600:1f1e:8eb:2401:5134:94f2:d33d:9e3d";
    };

    mainnet1-rel-eu3-1 = {
      privateIpv4 = "172.31.34.94";
      publicIpv4 = "13.39.54.80";
      publicIpv6 = "2a05:d012:382:9202:55f1:674b:4588:b47d";
    };

    mainnet1-rel-jp-1 = {
      privateIpv4 = "172.31.11.126";
      publicIpv4 = "54.64.212.17";
      publicIpv6 = "2406:da14:126:1601:87e1:7cde:73e7:e642";
    };

    mainnet1-rel-sa-1 = {
      privateIpv4 = "172.31.16.208";
      publicIpv4 = "13.245.173.80";
      publicIpv6 = "2406:da11:9a2:5702:b7d2:f02e:26c6:68f";
    };

    mainnet1-rel-sg-1 = {
      privateIpv4 = "172.31.42.6";
      publicIpv4 = "52.77.93.228";
      publicIpv6 = "2406:da18:152:b301:cb16:344c:1bf2:b489";
    };

    mainnet1-rel-us1-1 = {
      privateIpv4 = "172.31.11.4";
      publicIpv4 = "54.193.81.130";
      publicIpv6 = "2600:1f1c:7a0:d400:1638:341:aa:93c4";
    };

    mainnet1-rel-us2-1 = {
      privateIpv4 = "172.31.21.171";
      publicIpv4 = "18.116.18.69";
      publicIpv6 = "2600:1f16:ace:2e01:f3a8:272e:136d:b2d2";
    };
  };
in {
  flake.nixosModules.ips = all;
  flake.nixosModules.ip-module = {
    name,
    lib,
    ...
  }: {
    options.ips = {
      privateIpv4 = lib.mkOption {
        type = lib.types.str;
        default = all.${name}.privateIpv4 or "";
      };
      publicIpv4 = lib.mkOption {
        type = lib.types.str;
        default = all.${name}.publicIpv4 or "";
      };
      publicIpv6 = lib.mkOption {
        type = lib.types.str;
        default = all.${name}.publicIpv6 or "";
      };
    };
  };
}
