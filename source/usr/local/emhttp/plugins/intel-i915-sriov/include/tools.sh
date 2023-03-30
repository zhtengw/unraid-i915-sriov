#!/bin/bash

function get_pf_pci(){
    echo -n "$(lspci -D | grep -E "VGA compatible controller|Display controller" | grep "Intel" | awk '{print $1}' | sort | grep "\.0")"
}

function get_sriov_support(){
    PF_PCI=$(get_pf_pci)
    echo -n "$(lspci -vs ${PF_PCI} | grep "SR-IOV")"
}

function get_vfs_pci(){
    echo -n "$(lspci -D | grep -E "VGA compatible controller|Display controller" | grep "Intel" | awk '{print $1}' | sort | grep -v "\.0")"
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
    echo $1 > /sys/devices/pci${PF_PCI%:*}/${PF_PCI}/sriov_numvfs
}

$@
