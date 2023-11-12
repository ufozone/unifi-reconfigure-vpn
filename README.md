UniFi: Configure IPsec VTI VPN with dynamic IP on one or both sites
=========

**ATTENTION: The script only works for a bidirectional site-to-site VPN.**

Development & Pull Request
-----------

Feel free to enhance the script. Pull requests against the master branch will be reviewed and merged.

Installation
-----------

### Settings in Controller
Nothing to do in controller.

### Set-up script and configuration on USGs

SSH connection to both USG for the following commands:

```
admin@USG-Pro-4:~$ sudo touch /config/scripts/post-config.d/vpn-site-to-site-reconfigure.sh
admin@USG-Pro-4:~$ sudo chmod +x /config/scripts/post-config.d/vpn-site-to-site-reconfigure.sh
admin@USG-Pro-4:~$ sudo vi /config/scripts/post-config.d/vpn-site-to-site-reconfigure.sh
```

Input the content of the `vpn-site-to-site-reconfigure.sh`.

Create configuration file with following commands:

```
admin@USG-Pro-4:~$ sudo touch /config/vpn-site-to-site.conf
admin@USG-Pro-4:~$ sudo vi /config/vpn-site-to-site.conf
```

Input the content of the `vpn-site-to-site.conf`.

Change the variables:
| Variable          | Description                                                        | Values                       |
|-------------------|--------------------------------------------------------------------|------------------------------|
| THIS_SITE         | Letter of current site. Each site must be different from the other | ENUM(A,B)                    |
| SITE_A_HOST       | Hostname of site A                                                 | FQDN with final point        |
| SITE_B_HOST       | Hostname of site B                                                 | FQDN with final point        |
| SITE_A_NETWORKS   | Networks of site A which are to be routed                          | CIDR format space seperated  |
| SITE_B_NETWORKS   | Networks of site B which are to be routed                          | CIDR format space seperated  |
| PRE_SHARED_SECRET | Pre shared key                                                     | Secret with 24 or more bytes |
| VTI_BIND          | Name of Virtual Tunnel Interface                                   | vti[0-255] Default: vti64    |
| ESP_GROUP         | Name of ESP Group                                                  | ESP[0-255] Default: ESP0     |
| IKE_GROUP         | Name of IKE Group                                                  | IKE[0-255] Default: IKE0     |

Make sure to convert both files to LF.

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
Merge the contents of the `config.gateway.merge.json` in your `config.gateway.json` for both sites.

__You have no idea how to find or create the config.gateway.json?__
Check this: [UniFi - USG Advanced Configuration Using config.gateway.json](https://help.ui.com/hc/en-us/articles/215458888-UniFi-USG-Advanced-Configuration-Using-config-gateway-json)

Known Issues
-----------

### Gateway (USG) of the other side is not reachable, but "ping" and "traceroute" works
Long story short: You have to set a custom MSS clamping value in UniFi controller for both sites.

Legacy UI:
"Devices" > Click on USG > "Config" > "Advanced"

New UI:
"UniFi Devices" > Click on USG > "Settings" > "Services"

In my case, I have set the value to 1328, because pppoe interface has MTU 1492 and vti interface get MTU 1436.

For more information, see this community thread: [Site-to-site VPN and MSS clamping](https://community.ui.com/questions/Site-to-site-VPN-and-MSS-clamping/9ec02bdb-f327-4e6e-9199-bbdc5f639904)

### Gateway (USG) can not reach remote networks
The perfect explanation can be found here: [IPSEC Auto VPN and ping router-to-router](https://community.ui.com/questions/IPSEC-Auto-VPN-and-ping-router-to-router/c97b532b-e7fe-4f4a-9b90-54624b12b53d)

If the problem affects you, you only need to replace the script on the USG(s) with version 2.2 (or higher). Since this version, the script generates a static route to 10.255.254.0/24, which points to the VTI bind.

Troubleshooting
-----------

The script catches some error conditions. In verbose mode the whole "magic" can be displayed. Activate the verbose mode with the `-v` option:

```
admin@USG-Pro-4:~$ /config/scripts/post-config.d/vpn-site-to-site-reconfigure.sh -v
```

Below the errors and their solution explained:

### File vpn-site-to-site.conf not found. Abort.
You didn't create the file `vpn-site-to-site.conf` at all or you created it in the wrong folder.

Accomplish the following instructions carefully:
[Set-up script and configuration on USGs](#set-up-script-and-configuration-on-usgs)

### Configuration in vpn-site-to-site.conf is invalid. Abort.
The site-to-site VPN variables are not set or set incorrectly in the configuration. Check the variables for completeness and validity.

Accomplish the following instructions carefully:
[Set-up script and configuration on USGs](#set-up-script-and-configuration-on-usgs)

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
Same issue as [No local address found. Abort.](#no-local-address-found-abort) See above.


Compatibility
-------

Tested and productive in use:
* Ubiquiti UniFi Security Gateway, USG with FW 4.4.57.5578372
* Ubiquiti UniFi Security Gateway, USG-PRO-4 with FW 4.4.57.5578372

License
-------

MIT