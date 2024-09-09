Savannah-sc is compatible with DPDK library BBDev, this README page aims to help connect ACC100 to your server and start construct your own unit test/testcase. 
* Savannah-sc has been tested with dpdk version 21.11.2lts

## DPDK installation
  * [DPDK](http://core.dpdk.org/download/) version 21.11.2 lts
  * It is required you enable hugepage support and run agora under sudo permissions (LD_LIBRARY_PATH=${LD_LIBRARY_PATH}).
    <pre>
    $ sudo sh -c "echo 4 > /sys/devices/system/node/node0/hugepages/hugepages-1048576kB/nr_hugepages"
    $ sudo sh -c "echo 4 > /sys/devices/system/node/node1/hugepages/hugepages-1048576kB/nr_hugepages"
    </pre>
    Make memory available for dpdk
    <pre>
    $ mkdir /mnt/huge
    $ mount -t hugetlbfs nodev /mnt/huge
    </pre>
    Check hugepage usage
    <pre>
    $ cat /proc/meminfo
    </pre>
    [Building] https://doc.dpdk.org/guides/linux_gsg/sys_reqs.html#building-dpdk-applications

  * Mellanox's DPDK support depends on libibverbs / libmlx5 / ibverbs-utils.
  * Intel NICs may require the user to bring down the interface and load a DPDK compatible driver (vfio / pci_generic)
  * To install version 21.11.1, run
    <pre>
    $ meson build && cd build && ninja
    $ sudo ninja install
    $ sudo ldconfig
    </pre>
    the MLX poll mode driver will be autodetected and installed if required

## Integrate ACC100 to system:
 * ACC100 requires PCI Express x16 slot. 
 * If you are trying to run virtual functions, please make sure BIOS is providing enough MMIO space.
 * Please also make sure SR-IOV is enabled in BIOS: F2 BIOS > System BIOS > Integrated Devices > SR-IOV Global Enable
 * Please make sure the following is added to your GRUB settings:
   <pre>
    GRUB_CMDLINE_LINUX_DEFAULT="intel_iommu=on amd_iommu=on quiet splash vfio-pci.ids=ca:00.0 vfio_pci.enable_sriov=1 vfio_pci.disable_idle_d3=1 hugepage=64"
    GRUB_CMDLINE_LINUX="intel_iommu=on amd_iommu=on iommu=pt"
   <pre>

## Building and running Agora and emulated RRU with DPDK
 * Build Agora and emulated RRU with DPDK enabled.
    <pre>
    $ cd Agora
    $ mkdir build
    $ cd build
    $ cmake -DUSE_DPDK=true ..
    $ make -j
    </pre>

 * Run Agora with emulated RRU traffic with DPDK 
   * **NOTE**: For DPDK test, we run Agora and the emulated RRU on two different machines.
     Most DPDK installations will require you to run under sudo permissions. 
   * To generate data file, first return to the base directory (`cd ..`), then run
   <pre>
   $ ./build/data_generator --conf_file files/config/ci/tddconfig-sim-ul.json
   </pre>
   * To start Agora with uplink configuration, on one machine, run 
   <pre>
   $ sudo LD_LIBRARY_PATH=${LD_LIBRARY_PATH} ./build/agora --conf_file files/config/ci/tddconfig-sim-ul.json
   </pre>
    
   * To start the emulated RRU with uplink configuration, on another machine, run
   <pre>
   $ sudo LD_LIBRARY_PATH=${LD_LIBRARY_PATH} ./build/sender --num_threads=2 --core_offset=1 --enable_slow_start=1 --conf_file=files/config/ci/tddconfig-sim-ul.json --server_mac_addr=FF:FF:FF:FF:FF:FF
   </pre>
   Change the MAC address in `--server_mac_addr=` to the MAC address of the NIC used by Agora. 
   
