# YazDHCP
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/1f193c7b92a34b60bc1ef9a647f04908)](https://www.codacy.com/gh/jackyaz/YazDHCP/dashboard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=jackyaz/YazDHCP&amp;utm_campaign=Badge_Grade)
![Shellcheck](https://github.com/jackyaz/YazDHCP/actions/workflows/shellcheck.yml/badge.svg)

## v1.0.3
### Updated on 2021-12-23
## About
Feature expansion of DHCP assignments using AsusWRT-Merlin's [Addons API](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Addons-API) to read and write DHCP assignments, increasing the limit on the number of reservations.

YazDHCP is free to use under the [GNU General Public License version 3](https://opensource.org/licenses/GPL-3.0) (GPL 3.0).

### Supporting development
Love the script and want to support future development? Any and all donations gratefully received!

| [![paypal](https://www.paypalobjects.com/en_GB/i/btn/btn_donate_LG.gif)](https://www.paypal.com/donate/?hosted_button_id=47UTYVRBDKSTL) <br /><br /> [**PayPal donation**](https://www.paypal.com/donate/?hosted_button_id=47UTYVRBDKSTL) | [![paypal](https://puu.sh/IAhtp/3788f3a473.png)](https://www.paypal.com/donate/?hosted_button_id=47UTYVRBDKSTL) |
| :----: | --- |

## Supported firmware versions
You must be running firmware Merlin 384.15/384.13_4 [Asuswrt-Merlin](https://asuswrt.lostrealm.ca/)

## Installation
Using your preferred SSH client/terminal, copy and paste the following command, then press Enter:

```sh
/usr/sbin/curl --retry 3 "https://raw.githubusercontent.com/jackyaz/YazDHCP/master/YazDHCP.sh" -o "/jffs/scripts/YazDHCP" && chmod 0755 /jffs/scripts/YazDHCP && /jffs/scripts/YazDHCP install
```

## Usage
YazDHCP leverages the existing [LAN - DHCP Server](http://router.asus.com/Advanced_DHCP_Content.asp) page in the AsusWRT-Merlin WebUI. It has been modified under the hood to read and write to files in /jffs/addons/YazDHCP.d/ via the Addons API.

This allows us to use a greater amount of storage (6KB vs 2.5-3KB) for DHCP host assignments.

To launch the command line menu for YazDHCP after installation, use:
```sh
YazDHCP
```

If you do not have Entware installed, you will need to use the full path:
```sh
/jffs/scripts/YazDHCP
```

## Changes made to dnsmasq configuration
YazDHCP adds 3 lines to dnsmasq.conf.add to configure DHCP reservations:
```sh
addn-hosts=/jffs/addons/YazDHCP.d/.hostnames # YazDHCP_hostnames
dhcp-hostsfile=/jffs/addons/YazDHCP.d/.staticlist # YazDHCP_staticlist
dhcp-optsfile=/jffs/addons/YazDHCP.d/.optionslist # YazDHCP_optionslist
```
addn-hosts contains a list of IP address to hostname mappings, for DNS resolution of DHCP reserved clients
dhcp-hostsfile contains a list of MAC address to IP address bindings, to reserve a DHCP IP address for a MAC address
dhcp-optsfile contains a list of MAC address to DNS server address bindings, to provide the specified DNS server as a DHCP option for a MAC address

## Help
Please post about any issues and problems here: [YazDHCP on SNBForums](https://www.snbforums.com/forums/asuswrt-merlin-addons.60/?prefix_id=31)
