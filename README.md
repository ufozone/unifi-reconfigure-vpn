# UniFi: Configure IPsec VTI VPN with dynamic IP on one or both sites

## Development & Pull Request

Feel free to enhance the script. Pull requests against the master branch will be reviewed and merged.

## Installation

### Settings in Controller

Nothing to do in controller.

### Set-up script and configuration on USGs

SSH connection to both USG for the following commands:

```bash
sudo touch /config/scripts/post-config.d/vpn-site-to-site-reconfigure.sh
sudo chmod +x /config/scripts/post-config.d/vpn-site-to-site-reconfigure.sh
sudo vi /config/scripts/post-config.d/vpn-site-to-site-reconfigure.sh
```

Input the content of the `vpn-site-to-site-reconfigure.sh`.

Create configuration file with following commands:

```bash
sudo touch /config/vpn-site-to-site.conf
sudo vi /config/vpn-site-to-site.conf
```

Input the content of the `vpn-site-to-site.conf`.

Change these variables:
| Variable          | Description                                                        | Values                                  |
|-------------------|--------------------------------------------------------------------|-----------------------------------------|
| LOCAL_HOST        | Hostname of this site                                              | FQDN with final point                   |
| REMOTE_HOST       | Hostname of the remote site                                        | FQDN with final point                   |
| REMOTE_NETWORKS   | Networks of the remote site which are to be routed                 | CIDR format space seperated             |
| PRE_SHARED_SECRET | Pre shared key                                                     | Secret with 24 or more bytes            |
| TRANSFER_NETWORK  | Transfer network                                                   | CIDR format. Default: "10.255.254.0/24" |
| TRANSFER_ADDRESS  | Address of this site in the transfer network                       | CIDR format. Default: "10.255.254.1/32" |

For more than one IPsec site-to-site setup, further change these variables:
| Variable                | Description                                                  | Values                                  |
|-------------------------|--------------------------------------------------------------|-----------------------------------------|
| VTI_BIND                | Name of Virtual Tunnel Interface                             | vti[0-255] Default: vti64               |
| ESP_GROUP               | Name of ESP Group                                            | ESP[0-255] Default: ESP0                |
| IKE_GROUP               | Name of IKE Group                                            | IKE[0-255] Default: IKE0                |

Further additional variables are documented in the `vpn-site-to-site.conf`.

Make sure to convert both files to LF.

Execute the script:

```bash
/config/scripts/post-config.d/vpn-site-to-site-reconfigure.sh -v
```

Check the logs:

```bash
show log | grep 'vpn-site-to-site-reconfigure'
```

After the first run, your output should look like this:

```text
Feb 20 10:15:01 USG-Pro-4 vpn-site-to-site-reconfigure: VTI interface vti64 not found in configuration. Create.
Feb 20 10:15:01 USG-Pro-4 vpn-site-to-site-reconfigure: Static route 10.255.254.0/24 not found. Create.
Feb 20 10:15:01 USG-Pro-4 vpn-site-to-site-reconfigure: Static route 10.2.1.0/24/24 not found. Create.
Feb 20 10:15:02 USG-Pro-4 vpn-site-to-site-reconfigure: Firewall group item 10.2.1.0/24/24 not found. Create.
Feb 20 10:15:02 USG-Pro-4 vpn-site-to-site-reconfigure: Static route 10.2.2.0/24/24 not found. Create.
Feb 20 10:15:02 USG-Pro-4 vpn-site-to-site-reconfigure: Firewall group item 10.2.2.0/24/24 not found. Create.
Feb 20 10:15:02 USG-Pro-4 vpn-site-to-site-reconfigure: ESP group ESP0 not found in configuration. Create.
Feb 20 10:15:03 USG-Pro-4 vpn-site-to-site-reconfigure: IKE group IKE0 not found in configuration. Create.
Feb 20 10:15:03 USG-Pro-4 vpn-site-to-site-reconfigure: No site-to-site peer configuration found.
Feb 20 10:15:03 USG-Pro-4 vpn-site-to-site-reconfigure: Set up new site-to-site peer configuration.
Feb 20 10:15:05 USG-Pro-4 vpn-site-to-site-reconfigure: Commit configuration.
```

Until an IP address change, your output should normally look like this:

```text
Feb 20 10:20:03 USG-Pro-4 vpn-site-to-site-reconfigure: Remote address does not change.
Feb 20 10:20:03 USG-Pro-4 vpn-site-to-site-reconfigure: Local address does not change.
Feb 20 10:20:03 USG-Pro-4 vpn-site-to-site-reconfigure: Nothing to commit.
```

### Edit config.gateway.json

Your `config.gateway.json` needs an addition.

#### You have no idea how to find or create the config.gateway.json?

Check this: [UniFi - USG Advanced Configuration Using config.gateway.json](https://help.ui.com/hc/en-us/articles/215458888-UniFi-USG-Advanced-Configuration-Using-config-gateway-json)

#### Set-up (only) one site-to-site VPN IPsec tunnel

Merge the contents of the `config.gateway.merge.json` in your `config.gateway.json` for both sites.

#### Set-up multiple site-to-site VPN IPsec tunnels

Get the content of the `config.gateway.merge.json` and edit the task entry or rather add new task entries in the task scheduler as shown below:

```json
{
        "system": {
                "task-scheduler": {
                        "task": {
                                "vpn-site-to-site1": {
                                        "executable": {
                                                "path": "/config/scripts/post-config.d/vpn-site-to-site-reconfigure.sh",
                                                "arguments": "-c/config/vpn-site-to-site1.conf"
                                        },
                                        "interval": "5m"
                                },
                                "vpn-site-to-site2": {
                                        "executable": {
                                                "path": "/config/scripts/post-config.d/vpn-site-to-site-reconfigure.sh",
                                                "arguments": "-c/config/vpn-site-to-site2.conf"
                                        },
                                        "interval": "5m"
                                }
                        }
                }
        }
}
```

Make sure that each task has a unique name and that different configuration files are specified as arguments. After all, merge it in your `config.gateway.json` for all sites.

#### Provisioning and testing

Now the changes in your `config.gateway.json` must be provisioned to the USGs. You have no idea how? Click here: [How to Trigger provisioning after changing config.gateway.json](https://community.ui.com/questions/How-to-Trigger-provisioning-after-changing-config-gateway-json-in-Network-Controller-7-3-76/f105a191-7c2c-47ec-9bd1-9ca2d239d25b)

To check whether the tasks have been created on the USGs, you can use the following commands:

```bash
/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper show system task-scheduler
```

Normally you should get an output like the following:

```text
 task vpn-site-to-site {
     executable {
         path /config/scripts/post-config.d/vpn-site-to-site-reconfigure.sh
     }
     interval 5m
 }
```

## Known Issues

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

If the problem affects you, you only need to replace the script on the USG(s) with version 2.2 (or higher). Since this version, the script generates a static route to the transfer network (10.255.254.0/24), which points to the VTI bind (vti64 by default).

## Troubleshooting

The script catches some error conditions. In verbose mode the whole "magic" can be displayed. Activate the verbose mode with the `-v` option:

```bash
/config/scripts/post-config.d/vpn-site-to-site-reconfigure.sh -v
```

Below the errors and their solution explained:

### File vpn-site-to-site.conf not found. Abort

You didn't create the file `vpn-site-to-site.conf` at all or you created it in the wrong folder.

Accomplish the following instructions carefully:
[Set-up script and configuration on USGs](#set-up-script-and-configuration-on-usgs)

### Configuration in vpn-site-to-site.conf is invalid. Abort

The site-to-site VPN variables are not set or set incorrectly in the configuration. Check the variables for completeness and validity.

Accomplish the following instructions carefully:
[Set-up script and configuration on USGs](#set-up-script-and-configuration-on-usgs)

### No local address found. Abort

The hostnames for site A and site B must be valid and up-to-date dyndns hosts. The specified domains must have an A record.
You're sure about that? Your USG may not resolve domains. Try the following:

```bash
host -st A one.one.one.one
```

Expexted output:

```text
one.one.one.one has address 1.0.0.1
one.one.one.one has address 1.1.1.1
```

If the domain can't be resolved, your USG has a problem with the DNS it uses.

### No remote address found. Abort

Same issue as [No local address found. Abort.](#no-local-address-found-abort) See above.

## Compatibility

Tested and productive in use:

* Ubiquiti UniFi Security Gateway, USG-3P with FW 4.4.57.5578372
* Ubiquiti UniFi Security Gateway, USG-PRO-4 with FW 4.4.57.5578372

## License

MIT
