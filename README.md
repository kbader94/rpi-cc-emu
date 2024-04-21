# rpi-cc-emu

## Intro
  rpi-cc-emu is a script which attempts to automate the build and emulation of any linux kernel for any raspberry pi. Under the hood the script will cross compile a linux kernel with:
  * recommended architecture and kernel configurations for the raspberry pi
  * recommended kernel configuration for qemu emulation
  * optional kernel configurations for debugging the kernel

  Once a kernel is compiled with the desired configuration options, the script can modify the rootfs of a specified version of RaspiOS or Raspbian OS version in order to enable emulation via qemu, as well as install and set as active the newly compiled linux kernel, modules, and device tree blobs. After successfully setting up a kernel and rootfs, the script will be able to automatically configure qemu with the best options to emulate the newly compiled linux for the specified RasperryPi system. Additionally, after setting up the kernel and rootfs, the resulting RaspiOS disk image is able to be both emulated via qemu AND installed directly to real RasperryPi HW.

## Usage

  Basic shell install and run instructions go here

### Default - Interactive Mode

  With no parameters provided, the script will run in interactive mode by default. In this mode the script will walk you through a variety of options to configure an emulation environment for a specific model of Raspberry Pi.

## Common Parameters

### RPI Version



### Linux Kernel Version



### RaspiOS Version



## Other Parameters

--debug    Runs the script in debug mode, any exceptions are ignored and the script continues to execute. For script development use             only.

--verbose  Output extra information such as variable and parameter values 
