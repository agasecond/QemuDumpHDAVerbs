 QemuDumpHDAVerbs

Tools to dump audio codec(s) init and working verbs from Windows drivers

1.CPU must support virtualization extensions (VT-x for Intel)
    CPU must support Directed I/O (VT-d for Intel, generically known as IOMMU)
    Motherboard must support VT-x and VT-d (or AMD equivalents). 

2.Your CPU should fully support ACS if you don't want to worry about IOMMU groupings.

3.Grab Ubuntu 20.10 https://ubuntu.com/#download and create bootable flash drive(for windows I recommend using rufus https://rufus.ie/ for it), dont forget to turn safeboot off.

4.Install it and update packages # sudo apt update && sudo apt upgrade -y

5.Download custom patched prebuild kernel with ACS support(on the moment of publication it is 5.10.4), it allows you to pass devices to VM one by one.
    https://gitlab.com/Queuecumber/linux-acs-override/-/jobs/940850127/artifacts/download
    There is no need to build it, just download deb packets.

6.Install new kernel with sudo dpkg -i *.deb and reboot afterwards.

7.Make sure you are booting using new kernel, at the grub boot select choose advanced option and assure primary boot option is
    the kernel with suffix like -5.10.4-acso

8.Figure out parameters of your sound card by using # lspci -nn
    for example 05:00.6 Audio device [0403]: Advanced Micro Devices, Inc. [AMD] Family 17h (Models 10h-1fh) HD Audio Controller [1022:15e3]
    Mention address (in this example in the left part -> 05:00.6) and model number (in the right part -> 1022:15e3)

9.If you have multiple sound cards, you will need those numbers from them as well.

10.Edit your kernel boot options by editing GRUB # sudo nano /etc/default/grub
    GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amd_iommu=on intel_iommu=on iommu=pt pcie_acs_override=downstream,multifunction vfio-pci.ids=1022:15e3"

    vfio-pci.ids is comma separated pairs of 4 hex numbers - model of your sound card(s). amd_iommu or intel_iommu depending on your CPU.

11.Now it is time to check if we set it up correctly. Update GRUB # sudo update-grub and reboot.
    Once again, it is important that you boot to kernel with -acs suffix as mentioned above in p. 7

12.Check that your sound card are the only device bound to specific IOMMU group.
    #for dp in $(find /sys/kernel/iommu_groups/*/devices/*); do ploc=$(basename $dp | sed 's/0000://'); igrp=$(echo $dp | awk -F/ '{print $5}'); dinfo=$(lspci -nn | grep -E "^$ploc"); echo "[IOMMU $igrp] $dinfo" ; done 

    Example output:

    [IOMMU 20] 05:00.6 Audio device [0403]: Advanced Micro Devices, Inc. [AMD] Family 17h (Models 10h-1fh) HD Audio Controller [1022:15e3]
    [IOMMU 2] 00:01.2 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] Renoir PCIe GPP Bridge [1022:1634]
    [IOMMU 3] 00:01.3 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] Renoir PCIe GPP Bridge [1022:1634]
    [IOMMU 4] 00:02.0 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Renoir PCIe Dummy Host Bridge [1022:1632]
    [IOMMU 5] 00:02.1 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] Renoir PCIe GPP Bridge [1022:1634]
    [IOMMU 6] 00:08.0 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Renoir PCIe Dummy Host Bridge [1022:1632]
    [IOMMU 7] 00:08.1 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] Renoir Internal PCIe GPP Bridge to Bus [1022:1635]
    [IOMMU 8] 00:08.2 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] Renoir Internal PCIe GPP Bridge to Bus [1022:1635]
    [IOMMU 9] 00:14.0 SMBus [0c05]: Advanced Micro Devices, Inc. [AMD] FCH SMBus Controller [1022:790b] (rev 51)
    [IOMMU 9] 00:14.3 ISA bridge [0601]: Advanced Micro Devices, Inc. [AMD] FCH LPC Bridge [1022:790e] (rev 51)

    First row is what we are looking for. If you done all correctly and your system supports it, sound card will 
    be the only member of IOMMU group (in this example [IOMMU 20]).
    If there are multiple members of other devices in sound card IOMMU group you will have to either disable other devices or add them to vfio-pci.id list
    But this will not be covered in this guide.

13.Now we are ready to setup Qemu. Grab it sources # git clone https://git.qemu.org/git/qemu.git --recurse-submodules

14.Apply vfio.patch from this repo. Copy patch to qemu git root folder you just cloned and # git apply vfio.patch

15.Install dependencies # sudo apt install build-essential libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev libnfs-dev libiscsi-dev ninja-build

16.Configure it with 
    # ./configure \
    --enable-trace-backends=log \
    --target-list=x86_64-softmmu

17.Compile and install # sudo make -j$(nproc)   # sudo make install
    This should install qemu-system-x86_64 and other bins.

18.Now we are ready to setup VM. First create vm disk image with #qemu-img create -f qcow2 win.img 20G

19.Download Windows install ISO image and put it together with newly created disk image.

20.Boot up vm and install Windows as usually #qemu-system-x86_64 -enable-kvm -hda win.img -cdrom Windows10_x64_en-us_21286.iso -m 4G -smp 4

21.After installation turn off VM.

22.Edit startvm.sh script by setting your card address in host parameter.

    qemu-system-x86_64 -enable-kvm -M q35 -m 2G -boot d win.img -device vfio-pci,host=05:00.6 -vga std -smp 8 -monitor stdio 

23.We are ready to go :) Start VM with #sudo ./startvm.sh > log.txt
