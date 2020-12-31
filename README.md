# YazDHCP
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/1f193c7b92a34b60bc1ef9a647f04908)](https://www.codacy.com/gh/jackyaz/YazDHCP/dashboard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=jackyaz/YazDHCP&amp;utm_campaign=Badge_Grade)
[![Build Status](https://travis-ci.com/jackyaz/YazDHCP.svg?branch=master)](https://travis-ci.com/jackyaz/YazDHCP)

## v0.0.1
### Updated on 2020-12-24
## About
Feature expansion of DHCP assignments

YazDHCP is free to use under the [GNU General Public License version 3](https://opensource.org/licenses/GPL-3.0) (GPL 3.0).

### Supporting development
Love the script and want to support future development? Any and all donations gratefully received!

[**PayPal donation**](https://paypal.me/jackyaz21)

[**Buy me a coffee**](https://www.buymeacoffee.com/jackyaz)

![Menu UI](https://puu.sh/CNwF7/a095903835.png)

![Web UI](https://puu.sh/FbJeV/0f32c1da9d.png)

## Supported firmware versions
You must be running firmware Merlin 384.15/384.13_4 or Fork 43E5 (or later) [Asuswrt-Merlin](https://asuswrt.lostrealm.ca/)

## Installation
Using your preferred SSH client/terminal, copy and paste the following command, then press Enter:

```sh
/usr/sbin/curl --retry 3 "https://raw.githubusercontent.com/jackyaz/YazDHCP/master/YazDHCP.sh" -o "/jffs/scripts/YazDHCP" && chmod 0755 /jffs/scripts/YazDHCP && /jffs/scripts/YazDHCP install
```

## Usage
To launch the YazDHCP menu after installation, use:
```sh
YazDHCP
```

If you do not have Entware installed, you will need to use the full path:
```sh
/jffs/scripts/YazDHCP
```

## Help
Please post about any issues and problems here: [YazDHCP on SNBForums]()

## FAQs
### I haven't used scripts before on AsusWRT-Merlin
If this is the first time you are using scripts, don't panic! In your router's WebUI, go to the Administration area of the left menu, and then the System tab. Set Enable JFFS custom scripts and configs to Yes.

Further reading about scripts is available here: [AsusWRT-Merlin User-scripts](https://github.com/RMerl/asuswrt-merlin/wiki/User-scripts)

![WebUI enable scripts](https://puu.sh/A3wnG/00a43283ed.png)
