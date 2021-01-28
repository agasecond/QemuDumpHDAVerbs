#!/bin/bash

sudo qemu-system-x86_64 -enable-kvm -M q35 -m 2G -boot d win.img -device vfio-pci,host=05:00.6 -vga std -smp 8 -monitor stdio 
