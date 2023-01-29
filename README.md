UniFi: Reconfigure Auto IPsec VTI VPN with dynamic IP on one or both sites
=========

**ATTENTION: The script only works for a bidirectional site-to-site VPN. Furthermore, no other (automatic or manual) IPsec site-to-site VPN can be configured.**

Development & Pull Request
-----------
Feel free to enhance the script. Pull requests against the master branch will be reviewed and merged.

Installation
-----------

### Settings in Controller
If it doesn't exist yet, create an Auto IPsec VTI Site-to-Site VPN:
Go to Settings > Network > "Create new network"-button

| Variable      | Value                     |
|---------------|---------------------------|
| Name    		| _Name of your S2S_ 		|
| Purpose 		| Site-to-Site VPN     		|
| VPN Type		| Auto IPsec VTI     		|
| Remote Site	| _Site-B_		     		|

Wait for provisioning. After all, your site-to-site VPN connection between your local and the remote site is established.

One day your IP changes and then the script is there to fix it. ;-)

### Set-up script on USGs

SSH connection to both USG for the following commands:

```
admin@USG-Pro-4:~$ sudo touch /config/scripts/post-config.d/vpn-site-to-site-reconfigure.sh
admin@USG-Pro-4:~$ sudo chmod +x /config/scripts/post-config.d/vpn-site-to-site-reconfigure.sh
admin@USG-Pro-4:~$ sudo vi /config/scripts/post-config.d/vpn-site-to-site-reconfigure.sh
```

Input the content of the `vpn-site-to-site-reconfigure.sh`.

Change the variables:
| Variable          |Description                                                         | Values                       | Line |
|-------------------|--------------------------------------------------------------------|------------------------------|------|
| THIS_SITE         | Letter of current site. Each site must be different from the other | A or B                       |   11 |
| SITE_A_HOST       | Hostname of site A                                                 | FQDN with final point        |   14 |
| SITE_B_HOST       | Hostname of site B                                                 | FQDN with final point        |   15 |
| PRE_SHARED_SECRET | Pre shared key                                                     | Secret with 24 or more bytes |   18 |

Make sure to convert the file to LF.

Execute the script:

```
admin@USG-Pro-4:~$ /config/scripts/post-config.d/vpn-site-to-site-reconfigure.sh
```

Check the logs. Normally you should get an output like the following:

```
admin@USG-Pro-4:~$ show log | grep 'vpn-site-to-site-reconfigure'
Jan 29 21:06:07 USG-Pro-4 vpn-site-to-site-reconfigure: Remote address does not change.
Jan 29 21:06:07 USG-Pro-4 vpn-site-to-site-reconfigure: Local address does not change.
Jan 29 21:06:07 USG-Pro-4 vpn-site-to-site-reconfigure: Nothing to commit.
```

### Edit config.gateway.json

Your `config.gateway.json` needs an addition:
Merge the contents of the `config.gateway.sheduler.json` in your `config.gateway.json` for both sites.

__You have no idea how to find or create the config.gateway.json?__
Check this: [UniFi - USG Advanced Configuration Using config.gateway.json](https://help.ui.com/hc/en-us/articles/215458888-UniFi-USG-Advanced-Configuration-Using-config-gateway-json)

Troubleshooting
-----------

The script catches some error conditions. Below the errors and their solution explained:

### ESP group ESP0 not found in configuration. Abort.
You need to set up an Auto IPsec VTI site-to-site VPN connection in the controller. Did you make? Not good.

Let's debug it. Execute the following command. The output should look something like this:

```
admin@USG-Pro-4:~$ /opt/vyatta/sbin/vyatta-cfg-cmd-wrapper show vpn ipsec esp-group
esp-group ESP0 {
    compression disable
    lifetime 3600
    mode tunnel
    pfs enable
    proposal 1 {
        encryption aes256
        hash sha1
    }
}
```

If you get `Specified configuration path is not valid`, try the following:

```
admin@USG-Pro-4:~$ /opt/vyatta/sbin/vyatta-cfg-cmd-wrapper show vpn ipsec
auto-firewall-nat-exclude enable
esp-group ESP0 {
    compression disable
    lifetime 3600
    mode tunnel
    pfs enable
    proposal 1 {
        encryption aes256
        hash sha1
    }
}
ike-group IKE0 {
    dead-peer-detection {
        action restart
        interval 20
        timeout 120
    }
    key-exchange ikev1
    lifetime 28800
    proposal 1 {
        dh-group 14
        encryption aes256
        hash sha1
    }
}
ipsec-interfaces {
    interface pppoe0
}
nat-networks {
    allowed-network 0.0.0.0/0 {
    }
}
nat-traversal enable
...
```

The output is still empty? Then you do not have a valid IPsec VTI site-to-site VPN configuration. Is your USG provisioned since the VPN configuration?

### IKE group IKE0 not found in configuration. Abort.
Same issue as  _ESP group ESP0 not found in configuration. Abort._  See above.

### No local address found. Abort.
The hostnames for site A and site B must be valid and up-to-date dyndns hosts. The specified domains must have an A record.
You're sure about that? Your USG may not resolve domains. Try the following:

```
admin@USG-Pro-4:~$ host -st A one.one.one.one
one.one.one.one has address 1.0.0.1
one.one.one.one has address 1.1.1.1
```

If the domain can't be resolved, your USG has a problem with the DNS it uses.

### No remote address found. Abort.
Same issue as  _No local address found. Abort._  See above.


License
-------

MIT