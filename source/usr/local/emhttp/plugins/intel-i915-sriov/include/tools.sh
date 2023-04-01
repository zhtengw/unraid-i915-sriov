#!/bin/bash
PLUGIN="i915-sriov"

function get_pf_pci(){
    echo -n "$(lspci -D | grep -E "VGA compatible controller|Display controller" | grep "Intel" | awk '{print $1}' | grep "\.0" | sort -r | tail -1)"
}

function get_sriov_support(){
    PF_PCI=$(get_pf_pci)
    echo -n "$(lspci -vs ${PF_PCI} | grep "SR-IOV")"
}

function get_vfs_pci(){
    echo -n "$(lspci -D | grep -E "VGA compatible controller|Display controller" | grep "Intel" | awk '{print $1}' | grep -v "\.0" | sort)"
}

function get_vfs_num(){
    PF_PCI=$(get_pf_pci)
    echo -n "$(cat /sys/devices/pci${PF_PCI%:*}/${PF_PCI}/sriov_numvfs)"
}

function get_vfs_total(){
    PF_PCI=$(get_pf_pci)
    echo -n "$(cat /sys/devices/pci${PF_PCI%:*}/${PF_PCI}/sriov_totalvfs)"
}

function set_vfs_num(){
    PF_PCI=$(get_pf_pci)
    CFGFILE="/boot/config/plugins/${PLUGIN}/${PLUGIN}.cfg"
    if [ -f $CFGFILE ];then
        sed -i "s/\(vfnumber=\).*/\1$1/" ${CFGFILE} 
    else
        echo "vfnumber=$1" > ${CFGFILE} 
    fi
    echo $1 > /sys/devices/pci${PF_PCI%:*}/${PF_PCI}/sriov_numvfs
}

$@
