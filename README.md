# ethertetherpi
Bunch of scripts to convert a Raspberry Pi into a wired/wireless USB PTP DSLR camera tether companion.

## History
Initially this projects was OpenWRT/LEDE based because of two reasons. One it required a stable readonly power outage proof configuration (Raspberry on battery with disconnecting Power/USB without notice), which OpenWRT build scripts were capable of at that time(for me). Two it was based around qDslrDashboard(DDSERVER), but since the qDslrDashboard GUI App wasn't free anymore on some platforms I started to look for a alternative which let to something beyond original use case.

First I was looking at CLI libgphoto2 interaction but noticed that running it on a remote system without any monitor/controls attached will force me in writing/translating a lot of calls from the local Desktop/Notebook/Smartphone to the remote Raspberry Pi USB attached DSLR camera.
However by using a standard USB over IP implementation, I was able to expand from "Camera to qDslrDashboard GUI App" to almost any USB device on any OS communicating with its own control/drivers native to that OS. Since the control off the camera itself wasn't locked anymore in a PTP camera fashion (libgphoto2) to the USB host it was directly attached too, but the whole USB device was exposed over IP as in a local USB device being available on a virtual USB host controller on a Desktop running Ubuntu Linux, Microsoft Windows and even Apple MacOS(latter two may require proprietary/paid) USB-IP client implementation. 
Using a extra RPI0 in OTG USB gadget mode its possible to make a physical USB-IP <> IP-USB connection, which could be helpfull on devices without possibility of loading USB-IP virtual host controller drivers like smartphones (Android/IOS).

Like real USB there were also some caveats, like background daemons on the Desktop OS triggering/locking down the Camera in a MassStorage like behaviour for file transfer as soon as connecting the Camera and therefor blocking Apps like Darktable or qDslrDashboard to tether with it directly until you have freed the Camera from the other App. Also USB over IP via WiFi with a lot of packetloss will give some annoying connecting/disconnecting behaviour. Another issue was the availability of kernel/userspace based configuration tools for USB IP in different Linux Distributions, which were obsolete/missing and needed custom builds.

Since raspbian-lite OS is able to operate in a readonly way and Raspberry Pi 3b+ has improved wireless features its interesting to investigate again.

## Current
Complete build scripts are missing and incomplete but will start from OpenWRT leftovers and transform former project in raspbian-lite based appliance with multiple server/client roles in way's of tether/storage connectivity.

## Requirements
* Server (host that will share the USB device)
  - Raspberry-Pi(zero-w)
  - SD card (microSD 2GB)
  - USB cable-OTG (micro USB male to USB female)
  - USB Camera Cable
  - USB charger (powerbank for true wireless/mobility)

* Client (Linux):
  - usbip kernelmodule and corresponding userspace binaries 
  - https://github.com/solarkennedy/wiki.xkyle.com/wiki/USB-over-IP-On-Ubuntu

* Client (Windows / MacOS):
  - (test)https://sourceforge.net/projects/usbip/files/usbip_windows/
  - (test)https://www.virtualhere.com/usb_client_software
