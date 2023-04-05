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

function set_cfg(){
    CFGFILE="/boot/config/plugins/${PLUGIN}/${PLUGIN}.cfg"
    if [ -f $CFGFILE ];then
        sed -i "s/\(vfnumber=\).*/\1$1/" ${CFGFILE} 
    else
        echo "vfnumber=$1" > ${CFGFILE} 
    fi
}

function bind_vfio(){
    # $1 args should be dddd:bb:ss.f
    PCI=$1
    dsp="/sys/devices/pci${PCI%:*}/${PCI}"
    dpath="$dsp/driver"
    dbdf=${dsp##*/}

    echo "vfio-pci" > "$dsp/driver_override"

    if [[ -d $dpath ]]; then
        curr_driver=$(readlink $dpath)
        curr_driver=${curr_driver##*/}

        if [[ "$curr_driver" == "vfio-pci" ]]; then
            echo "${dbdf} already bound to vfio-pci"
            continue
        else
            echo $dbdf > "$dpath/unbind"
            echo "Unbound ${dbdf} from ${curr_driver}"
        fi
    fi

    echo $dbdf > /sys/bus/pci/drivers_probe
}

function set_vfs_num(){
    PF_PCI=$(get_pf_pci)
    set_cfg $1

    echo 0 > /sys/devices/pci${PF_PCI%:*}/${PF_PCI}/sriov_numvfs
    sleep 2
    echo $1 > /sys/devices/pci${PF_PCI%:*}/${PF_PCI}/sriov_numvfs
    
    VF_PCI=$(get_vfs_pci)
    for pci in ${VF_PCI}
    do
        bind_vfio $pci
    done
}

$@
