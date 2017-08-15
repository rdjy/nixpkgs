{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.bind;
n
  bindUser = "named";

  confFile = pkgs.writeText "named.conf"
    ''
      include "/etc/bind/rndc.key";
      controls {
        inet 127.0.0.1 allow {localhost;} keys {"rndc-key";};
      };

      acl cachenetworks { ${concatMapStrings (entry: " ${entry}; ") cfg.cacheNetworks} };
      acl badnetworks { ${concatMapStrings (entry: " ${entry}; ") cfg.blockedNetworks} };

      options {
        listen-on { ${concatMapStrings (entry: " ${entry}; ") cfg.listenOn} };
        listen-on-v6 { ${concatMapStrings (entry: " ${entry}; ") cfg.listenOnIpv6} };
        allow-query { cachenetworks; };
        blackhole { badnetworks; };
        forward first;
        forwarders { ${concatMapStrings (entry: " ${entry}; ") cfg.forwarders} };
        directory "/var/run/named";
        pid-file "/var/run/named/named.pid";
      };

      ${cfg.extraConfig}

      ${ concatMapStrings
          ({ name, file, master ? true, slaves ? [], masters ? [], extraConfig? "" }:
            ''
              zone "${name}" {
                type ${if master then "master" else "slave"};
                file "${file}";
                ${ if master then
                   ''
                     allow-transfer {
                       ${concatMapStrings (ip: "${ip};\n") slaves}
                     };
                   ''
                   else
                   ''
                     masters {
                       ${concatMapStrings (ip: "${ip};\n") masters}
                     };
                   ''
                }
                allow-query { any; };
              };
	      ${extraConfig}
            '')
          cfg.zones }
    '';

in

{

  ###### interface

  options = {

    services.bind = {

      enable = mkOption {
        default = false;
        description = "
          Whether to enable BIND domain name server.
        ";
      };

      cacheNetworks = mkOption {
        default = ["127.0.0.0/24"];
        description = "
          What networks are allowed to use us as a resolver.
        ";
      };

      blockedNetworks = mkOption {
        default = [];
        description = "
          What networks are just blocked.
        ";
      };

      ipv4Only = mkOption {
        default = false;
        description = "
          Only use ipv4, even if the host supports ipv6.
        ";
      };

      forwarders = mkOption {
        default = config.networking.nameservers;
        description = "
          List of servers we should forward requests to.
        ";
      };

      listenOn = mkOption {
        default = ["any"];
        type = types.listOf types.str;
        description = "
          Interfaces to listen on.
        ";
      };

      listenOnIpv6 = mkOption {
        default = ["any"];
        type = types.listOf types.str;
        description = "
          Ipv6 interfaces to listen on.
        ";
      };

      zones = mkOption {
        default = [];
        description = "
          List of zones we claim authority over.
            master=false means slave server; slaves means addresses
           who may request zone transfer.
        ";
        example = [{
          name = "example.com";
          master = false;
          file = "/var/dns/example.com";
          masters = ["192.168.0.1"];
          slaves = [];
        }];
      };

      extraConfig = mkOption {
        type = types.lines;
        default = "";
        description = "
          Extra lines to be added verbatim to the generated named configuration file.
        ";
      };

      configFile = mkOption {
        type = types.path;
        default = confFile;
        defaultText = "confFile";
        description = "
          Overridable config file to use for named. By default, that
          generated by nixos.
        ";
      };

    };

  };


  ###### implementation

  config = mkIf config.services.bind.enable {

    users.extraUsers = singleton
      { name = bindUser;
        uid = config.ids.uids.bind;
        description = "BIND daemon user";
      };

    systemd.services.bind = {
      description = "BIND Domain Name Server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        mkdir -m 0755 -p /etc/bind
        if ! [ -f "/etc/bind/rndc.key" ]; then
          ${pkgs.bind.out}/sbin/rndc-confgen -r /dev/urandom -c /etc/bind/rndc.key -u ${bindUser} -a -A hmac-sha256 2>/dev/null
        fi

        ${pkgs.coreutils}/bin/mkdir -p /var/run/named
        chown ${bindUser} /var/run/named
      '';

      serviceConfig = {
        ExecStart  = "${pkgs.bind.out}/sbin/named -u ${bindUser} ${optionalString cfg.ipv4Only "-4"} -c ${cfg.configFile} -f";
        ExecReload = "${pkgs.bind.out}/sbin/rndc -k '/etc/bind/rndc.key' reload";
        ExecStop   = "${pkgs.bind.out}/sbin/rndc -k '/etc/bind/rndc.key' stop";
      };

      unitConfig.Documentation = "man:named(8)";
    };
  };
}
