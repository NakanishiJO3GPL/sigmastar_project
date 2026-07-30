#!/bin/sh

PROJ_ROOT=$PWD

if [ "$#" != "1" ] && [ "$#" != "2" ]&& [ "$#" != "3" ]; then
    echo "usage: $0 configs/config.chip"
    echo "or $0 configs/config.chip config.out"
    exit -1
fi

INPUT_CONFIG=$1
if [ ! -e  $INPUT_CONFIG ]; then
    echo "can't find $INPUT_CONFIG"
    exit -1
fi

if [[ ${INPUT_CONFIG:0-9} == "defconfig" ]]; then
    $PROJ_ROOT/setup_defconfig.sh $INPUT_CONFIG
    exit
fi

OUTPUT_CONFIG=$PROJ_ROOT/configs/current.configs
if [ $# -ge 2 ]; then
    OUTPUT_CONFIG=$2
fi
ALKAID_MHAL_UT=0
if [ $# -ge 3 ]; then
    ALKAID_MHAL_UT=$3
fi
echo ======================================
echo ALKAID_MHAL_UT=$ALKAID_MHAL_UT
echo ======================================

CLANG_PREBUILT_BIN=kernel/prebuilts-master/clang/host/linux-x86/clang-r416183b/bin
LINUX_GCC_CROSS_COMPILE_PREBUILTS_BIN=kernel/prebuilts/gas/linux-x86
export PATH=$PATH:/tools/toolchain/android-ndk-r25b/toolchains/llvm/prebuilt/linux-x86_64/bin

if [ -e configs ]; then

    TOOLCHAIN=$(sed -n "/^TOOLCHAIN\b/p"  $1 | awk '{print $3}')
    if [ "$TOOLCHAIN" != "llvm" ]; then
        export PATH=/tools/bin/:$PATH
    else
        export PATH=/tools/bin:$PROJ_ROOT/../$CLANG_PREBUILT_BIN:$PROJ_ROOT/../$LINUX_GCC_CROSS_COMPILE_PREBUILTS_BIN:$PATH
    fi

    setup_chip=$(sed -n "/^CHIP\b/p"  $1 | awk '{print $3}')
    setup_toolchain_v=$(sed -n "/^TOOLCHAIN_VERSION\b/p"  $1 | awk '{print $3}')
    setup_cross_compile=$(sed -n "/^TOOLCHAIN_REL\b/p"  $1 | awk '{print $3}')
    if [ "$TOOLCHAIN" != "llvm" ]; then
        cur_toolchain_v=$(${setup_cross_compile}-gcc -dumpversion)
    else
        cur_toolchain_v=$(clang -dumpversion)
    fi

    linux_arch=$(sed -n "/LINUX_ARCH\b/p" $1 | awk '{print $3}')

    if [ -f /tools/bin/clang-13/clang-tidy ]; then
        clang_tidy=/tools/bin/clang-13/clang-tidy
        clang_format=/tools/bin/clang-13/clang-format
    else
        clang_tidy=$PROJ_ROOT/tools/clang-13/clang-tidy
        clang_format=$PROJ_ROOT/tools/clang-13/clang-format
    fi
    setup_clang_version=13.0.0
    current_clang_format_version=$($clang_format --version | grep 'version' | sed -r "s/.*version ([0-9]+\.[0-9]+.*).*/\1/g")
    current_clang_tidy_version=$($clang_tidy --version | grep 'version' | sed -r "s/.*version ([0-9]+\.[0-9]+.*).*/\1/g")

    if [ -f "$clang_format" ]; then

        version_check=$(echo ${current_clang_format_version} | grep ${setup_clang_version})
        if [[ "$version_check" != "" ]];then
            echo "current clang-format version:$current_clang_format_version"
        else
            echo "*********************************************************************"
            echo -e "\033[5;41;33m" "clang_format VERSION IS NOT MATCHED FOR  [ $setup_clang_version ]!" "\033[0m"
            echo "config request clang-format version is:[ $setup_clang_version ], but server clang-format version is:[ $current_clang_format_version ]."
            echo "*********************************************************************"
            exit
        fi
    else
        echo "$clang_format not exists."
        clang_format=''
    fi

    if [ -f "$clang_tidy" ]; then

        version_check=$(echo ${current_clang_tidy_version} | grep ${setup_clang_version})
        if [[ "$version_check" != "" ]];then
            echo "current clang-tidy version:$current_clang_tidy_version"
        else
            echo "*********************************************************************"
            echo -e "\033[5;41;33m" "clang_tidy VERSION IS NOT MATCHED FOR  [ $setup_clang_version ]!" "\033[0m"
            echo "config request clang-tidy version is:[ $setup_clang_version ], but server clang-tidy version is:[ $current_clang_tidy_version ]."
            echo "*********************************************************************"
            exit
        fi
    else
        echo "$clang_tidy not exists."
        clang_tidy=''
    fi

    if [ "$setup_toolchain_v" != "$cur_toolchain_v" ]; then
        echo "*********************************************************************"
        echo -e "\033[5;41;33m" "TOOLCHAIN VERSION IS NOT MATCHED FOR CHIP [ $setup_chip ]!" "\033[0m"
        echo "config request toolchain version is:[ $setup_toolchain_v ], but server toolchain version is:[ $cur_toolchain_v ]."
        echo "*********************************************************************"
        exit -1
    fi

    echo PROJ_ROOT = $PROJ_ROOT > $OUTPUT_CONFIG
    echo CONFIG_NAME = config_module_list.mk >> $OUTPUT_CONFIG
    echo KBUILD_MK = kbuild/kbuild.mk >> $OUTPUT_CONFIG
    echo SOURCE_MK = ../sdk/sdk.mk >> $OUTPUT_CONFIG
    echo UBOOT_MK = ./board/uboot/uboot.mk >> $OUTPUT_CONFIG
    echo RTOS_MK = ./board/rtos/rtos.mk >> $OUTPUT_CONFIG
    echo PM_RTOS_MK = ./board/pm_rtos/pm_rtos.mk >> $OUTPUT_CONFIG
    echo OPTEE_MK = ./board/optee/optee.mk >> $OUTPUT_CONFIG
    echo "KERNEL_MEMADR = \$(shell $PROJ_ROOT/image/makefiletools/bin/mmapparser $PROJ_ROOT/board/\$(CHIP)/mmap/\$(MMAP) \$(CHIP) E_LX_MEM phyaddr)" >> $OUTPUT_CONFIG
    echo "KERNEL_MEMLEN = \$(shell $PROJ_ROOT/image/makefiletools/bin/mmapparser $PROJ_ROOT/board/\$(CHIP)/mmap/\$(MMAP) \$(CHIP) E_LX_MEM size)" >> $OUTPUT_CONFIG
    echo "KERNEL_MEMADR2 = \$(shell $PROJ_ROOT/image/makefiletools/bin/mmapparser $PROJ_ROOT/board/\$(CHIP)/mmap/\$(MMAP) \$(CHIP) E_LX_MEM2 phyaddr)" >> $OUTPUT_CONFIG
    echo "KERNEL_MEMLEN2 = \$(shell $PROJ_ROOT/image/makefiletools/bin/mmapparser $PROJ_ROOT/board/\$(CHIP)/mmap/\$(MMAP) \$(CHIP) E_LX_MEM2 size)" >> $OUTPUT_CONFIG
    echo "KERNEL_MEMADR3 = \$(shell $PROJ_ROOT/image/makefiletools/bin/mmapparser $PROJ_ROOT/board/\$(CHIP)/mmap/\$(MMAP) \$(CHIP) E_LX_MEM3 phyaddr)" >> $OUTPUT_CONFIG
    echo "KERNEL_MEMLEN3 = \$(shell $PROJ_ROOT/image/makefiletools/bin/mmapparser $PROJ_ROOT/board/\$(CHIP)/mmap/\$(MMAP) \$(CHIP) E_LX_MEM3 size)" >> $OUTPUT_CONFIG
    echo "LOGO_ADDR = \$(shell $PROJ_ROOT/image/makefiletools/bin/mmapparser $PROJ_ROOT/board/\$(CHIP)/mmap/\$(MMAP) \$(CHIP) \$(BOOTLOGO_ADDR) miuaddr)" >> $OUTPUT_CONFIG
    cat $1 >> $OUTPUT_CONFIG
    if [ "$linux_arch" != "" ]; then
        echo "ARCH=$linux_arch" >> $OUTPUT_CONFIG
    else
        echo "ARCH=arm" >> $OUTPUT_CONFIG
    fi
    echo "CROSS_COMPILE=$(sed -n "/TOOLCHAIN_REL\b/p" $OUTPUT_CONFIG | awk '{print $3}')-" >> $OUTPUT_CONFIG
    echo "PYTHON=python" >> $OUTPUT_CONFIG

    c=$(sed -n "/^CHIP\b/p" $OUTPUT_CONFIG | awk '{print $3}')
    echo "CHIP_FULL_NAME = $c" >> $OUTPUT_CONFIG
    echo "CHIP_ALIAS = $c" >> $OUTPUT_CONFIG

    echo "PREFIX =\$(TOOLCHAIN_REL)-" >> $OUTPUT_CONFIG

    if [ "$TOOLCHAIN" != "llvm" ]; then
        echo "AS = \$(PREFIX)as" >> $OUTPUT_CONFIG
        echo "CC = \$(PREFIX)gcc" >> $OUTPUT_CONFIG
        echo "CXX = \$(PREFIX)g++" >> $OUTPUT_CONFIG
        echo "CPP = \$(PREFIX)cpp" >> $OUTPUT_CONFIG
        echo "LD = \$(PREFIX)ld" >> $OUTPUT_CONFIG
        echo "AR = \$(PREFIX)ar" >> $OUTPUT_CONFIG
        echo "STRIP = \$(PREFIX)strip" >> $OUTPUT_CONFIG
        echo "OBJCOPY = \$(PREFIX)objcopy" >> $OUTPUT_CONFIG
        echo "OBJDUMP = \$(PREFIX)objdump" >> $OUTPUT_CONFIG
    else
        ndk_clang_prefix=$(sed -n "/^NDK_CLANG_PREFIX\b/p" $OUTPUT_CONFIG | awk '{print $3}')
        ndk_binutils_prefix=$(sed -n "/^NDK_BINUTILS_PREFIX\b/p" $OUTPUT_CONFIG | awk '{print $3}')
        ndk_api_version=$(sed -n "/^NDK_API_VERSION\b/p" $OUTPUT_CONFIG | awk '{print $3}')
        ndk_clang_version=$(sed -n "/^NDK_CLANG_VERSION\b/p" $OUTPUT_CONFIG | awk '{print $3}')

        cur_ndk_clang_version=$(${ndk_clang_prefix}${ndk_api_version}-clang -dumpversion)

        if [ "${cur_ndk_clang_version}" != "${ndk_clang_version}" ];then
            echo "*********************************************************************"
            echo -e "\033[5;41;33m" "ndk clang version is not matched !!!" "\033[0m"
            echo "config request ndk clang version is:[ $ndk_clang_version ], but server ndk clang version is:[ $cur_ndk_clang_version ]."
            echo "*********************************************************************"
            exit -1
        fi

        ndk_path=$(dirname $(which ${ndk_clang_prefix}${ndk_api_version}-clang))

        echo "CC = ${ndk_path}/${ndk_clang_prefix}${ndk_api_version}-clang" >> $OUTPUT_CONFIG
        echo "CXX = ${ndk_path}/${ndk_clang_prefix}${ndk_api_version}-clang++" >> $OUTPUT_CONFIG
        echo "CPP = ${ndk_path}/${ndk_clang_prefix}${ndk_api_version}-clang++" >> $OUTPUT_CONFIG
        echo "AS = ${ndk_path}/${ndk_binutils_prefix}-as" >> $OUTPUT_CONFIG
        echo "LD = ${ndk_path}/${ndk_binutils_prefix}-ld" >> $OUTPUT_CONFIG
        echo "AR = ${ndk_path}/${ndk_binutils_prefix}-ar" >> $OUTPUT_CONFIG
        echo "NM = ${ndk_path}/${ndk_binutils_prefix}-nm" >> $OUTPUT_CONFIG
        echo "STRIP = ${ndk_path}/${ndk_binutils_prefix}-strip" >> $OUTPUT_CONFIG
        echo "OBJCOPY = ${ndk_path}/${ndk_binutils_prefix}-objcopy" >> $OUTPUT_CONFIG
        echo "OBJDUMP = ${ndk_path}/${ndk_binutils_prefix}-objdump" >> $OUTPUT_CONFIG

        echo "export KBUILD_CONFIGS = LLVM=1 LLVM_IAS=1 CC=clang CPP=\"clang -E\" LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf STRIP=llvm-strip" >> $OUTPUT_CONFIG
    fi

    echo "export ARCH CROSS_COMPILE" >> $OUTPUT_CONFIG
    echo "export PATH=$PATH" >> $OUTPUT_CONFIG

    if [[ "$clang_tidy" != '' && "$clang_format" != '' ]]; then
        echo "CLANG_TIDY = $clang_tidy" >> $OUTPUT_CONFIG
        echo "CLANG_FORMAT = $clang_format" >> $OUTPUT_CONFIG
        echo "export CLANG_TIDY CLANG_FORMAT" >> $OUTPUT_CONFIG
    fi

else
    echo "can't found configs directory!"
    exit -1
fi

p=$(sed -n "/^PRODUCT\b/p" $OUTPUT_CONFIG | awk '{print $3}')
if [[ "$p" == "android" ]]; then
    KERNEL_ROOT=$PROJ_ROOT/../kernel/common
else
    KERNEL_ROOT=$PROJ_ROOT/../kernel
fi
echo "KERNEL_ROOT = $KERNEL_ROOT" >> $OUTPUT_CONFIG

if [[ ! "$p" =~ "purertos" ]];then
    if [ -e "../kernel/" ];then
        KERNEL_MK="$KERNEL_ROOT/Makefile"
        VERSION=`sed -n "/^VERSION/p" $KERNEL_MK | tr -cd "[0-9]"`
        PATCHLEVEL=`sed -n "/^PATCHLEVEL/p" $KERNEL_MK | tr -cd "[0-9]"`
        SUBLEVEL=`sed -n "/^SUBLEVEL/p" $KERNEL_MK | tr -cd "[0-9]"`
        CUR_KERNEL_VERSION="$VERSION.$PATCHLEVEL.$SUBLEVEL"
        echo "CUR_KERNEL_VERSION = $CUR_KERNEL_VERSION" >> $OUTPUT_CONFIG
    else
        echo "can't find kernel directory!"
        exit -1
    fi
fi

CHIP=`cat $1 | awk '/CHIP/ {print substr($3,$1)}'`
MMAP=`cat $1 | awk '/MMAP/ {print substr($3,$1)}'`
kernel_reserved_env="mmap_reserved="
FBADDR=`$PROJ_ROOT/image/makefiletools/bin/mmapparser $PROJ_ROOT/board/$CHIP/mmap/$MMAP $CHIP E_MMAP_ID_FB phyaddr`
assemble_kernel_reserved_env()
{
	n=$#
	n=$(expr $n \/ 5 \- 1)
	for i in $(seq 0 $n)
	do
		j=$(expr $i \* 5)
		j=$(expr $j \+ 1)
		name=$(eval "echo \${$j}")
		name=$(tr [A-Z] [a-z] <<< $name)
		j=$(expr $j \+ 1)
		miu=$(eval "echo \${$j}")
		j=$(expr $j \+ 1)
		sz=$(eval "echo \${$j}")
		j=$(expr $j \+ 1)
		start=$(eval "echo \${$j}")
		j=$(expr $j \+ 1)
		end=$(eval "echo \${$j}")
		kernel_reserved_env+="$name,miu=$miu,sz=$sz,max_start_off=$start,max_end_off=$end "
		if [ "$name" == "bootlogo" ]; then
            sed -i "s/LOGO_ADDR = .*/LOGO_ADDR = $start/g" $OUTPUT_CONFIG
		fi
		if [ "$FBADDR" != "" ]; then
            sed -i "s/LOGO_ADDR = .*/LOGO_ADDR = $FBADDR/g" $OUTPUT_CONFIG
		fi
	done
}
data=`$PROJ_ROOT/image/makefiletools/bin/reserved $PROJ_ROOT/board/$CHIP/mmap/$MMAP $CHIP `
assemble_kernel_reserved_env $data

check_param_empty_and_delete()
{
    for x in $@;
    do
        param_value=$(sed -n "/^$x\b/p" $OUTPUT_CONFIG | awk '{print $3}')
        if [ ! -n "$param_value" ]; then
            line=$(grep -n $x $OUTPUT_CONFIG | cut -d: -f1)
            echo "param = null, delete $x line:$line"
            if [ -n "$line" ]; then
                sed -i "$(echo $line)d" $OUTPUT_CONFIG
            fi
        elif [[ ! "$param_value" =~ ^0x.* ]]; then
            echo -e "$x = $param_value parameter error, please check"
            exit -1
        fi
    done
}

DRAM_LAYOUT=$PROJ_ROOT/configs/dram_layout.txt
touch $DRAM_LAYOUT
dram_base_addr=0x20000000
INITRAMFSLOADADDR=0x21800000

dram_size=$(sed -n "/^DRAM_SIZE\b/p" $OUTPUT_CONFIG | awk -F' = ' '{print $2}')
lx_size=$(sed -n "/^LX_MEM_SIZE\b/p" $OUTPUT_CONFIG | awk -F' = ' '{print $2}')
mma_size=$(sed -n "/^MMA_MEM_SIZE\b/p" $OUTPUT_CONFIG | awk -F' = ' '{print $2}')
cma_size=$(sed -n "/^CMA_MEM_SIZE\b/p" $OUTPUT_CONFIG | awk -F' = ' '{print $2}')
logo_size=$(sed -n "/^LOGO_MEM_SIZE\b/p" $OUTPUT_CONFIG | awk -F' = ' '{print $2}')
smf_size=$(sed -n "/^SMF_MEM_SIZE\b/p" $OUTPUT_CONFIG | awk -F' = ' '{print $2}')
riscv_size=$(sed -n "/^RISCV_MEM_SIZE\b/p" $OUTPUT_CONFIG | awk -F' = ' '{print $2}')
riu_recorder_size=$(sed -n "/^RIU_RECORDER_MEM_SIZE\b/p" $OUTPUT_CONFIG | awk -F' = ' '{print $2}')
vmm_size=$(sed -n "/^VMM_MEM_SIZE\b/p" $OUTPUT_CONFIG | awk -F' = ' '{print $2}')
optee_size=$(sed -n "/^OPTEE_MEM_SIZE\b/p" $OUTPUT_CONFIG | awk -F' = ' '{print $2}')
tfa_size=$(sed -n "/^TFA_MEM_SIZE\b/p" $OUTPUT_CONFIG | awk -F' = ' '{print $2}')

if [ $dram_size == "0" ]; then
    echo "set dram_size is $dram_size!"
    exit -1
fi

if [ $(($dram_size % 0x100000)) != "0" ]; then
    echo "set dram_size is $dram_size not 1M alignmen!"
    exit -1
fi

if [ $lx_size == "0" ]; then
    echo "set lx_mem is $lx_size!"
    exit -1
fi

if [ $(($lx_size % 0x100000)) != "0" ]; then
    echo "set lx_size is $lx_size not 1M alignmen!"
    exit -1
fi

dram_end_addr=$(printf 0x%x $(echo $[ $dram_base_addr + $dram_size ]))
echo "DRAM:$dram_base_addr-$dram_end_addr" > $DRAM_LAYOUT
echo "MODULE:                        Start:                      End:                        size:" >> $DRAM_LAYOUT
lx_addr=$dram_base_addr
lx_end_addr=$(printf 0x%x $(echo $[ $dram_base_addr + $lx_size ]))

if [ $lx_size != "0" ]; then
    echo "LX                                   $lx_addr            $lx_end_addr             $lx_size" >> $DRAM_LAYOUT
fi

eval echo "KERNEL_LX_MEM = LX_MEM=$lx_size" >> $OUTPUT_CONFIG

cma_addr=$(printf 0x%x $(echo $[ $lx_size - $cma_size ]))
cma_end_addr=$lx_size

if [ $cma_size != "0" ]; then
    eval echo "KERNEL_RESERVED_CMA = cma=$(($cma_size / 0x100000))M" >> $OUTPUT_CONFIG
fi

logo_addr=$(printf 0x%x $(echo $[ $cma_addr - $logo_size ]))
logo_end_addr=$cma_addr

if [ $logo_size != "0" ]; then
    eval echo "KERNEL_RESERVED_LOGO = mmap_reserved=fb,miu=0,sz=$logo_size,max_start_off=$logo_addr,max_end_off=$logo_end_addr" >> $OUTPUT_CONFIG
fi

smf_addr=$(printf 0x%x $(echo $[ $logo_addr - $smf_size ]))
smf_end_addr=$logo_addr

if [ $smf_size != "0" ]; then
    eval echo "KERNEL_RESERVED_SMF = mmap_reserved=smf,miu=0,sz=$smf_size,max_start_off=$smf_addr,max_end_off=$smf_end_addr" >> $OUTPUT_CONFIG
fi

riscv_addr=$(printf 0x%x $(echo $[ $smf_addr - $riscv_size ]))
riscv_end_addr=$smf_addr

if [ $riscv_size != "0" ]; then
    eval echo "KERNEL_RESERVED_RISCV = mmap_reserved=riscv,miu=0,sz=$riscv_size,max_start_off=$riscv_addr,max_end_off=$riscv_end_addr" >> $OUTPUT_CONFIG
fi

rtos_enable=$(sed -n "/^RTOS_ENABLE\b/p" $OUTPUT_CONFIG | awk '{print $3}')
if [[ "$rtos_enable" == "on" ]]; then
    rtos_size=$(sed -n "/^RTOS_MEM_SIZE\b/p" $OUTPUT_CONFIG | awk -F' = ' '{print $2}')
    rtos_ramdisk_size=$(sed -n "/^RTOS_RAMDISK_MEM_SIZE\b/p" $OUTPUT_CONFIG | awk -F' = ' '{print $2}')
    rtos_timestamp_size=$(sed -n "/^RTOS_TIMESTAMP_MEM_SIZE\b/p" $OUTPUT_CONFIG | awk -F' = ' '{print $2}')

    rtos_defconfig=$(sed -n "/^RTOS_CONFIG\b/p" $OUTPUT_CONFIG | awk -F' = ' '{print $2}')
    RTOS_DEFCONFIG=$PROJ_ROOT/../rtos/proj/mak/defconfigs/$rtos_defconfig

    rtos_dynamic_load_en=$(sed -n "/^CONFIG_DYNAMIC_LOADING_ADDR_SUPPORT\b/p" $RTOS_DEFCONFIG | awk -F'=' '{print $2}')

    mma_addr=$lx_end_addr

    if [ $mma_size == 0 ]; then
        mma_end_addr=$(printf 0x%x $(echo $[ $dram_base_addr + $dram_size - $tfa_size - $optee_size - $vmm_size - $rtos_size ]))
        mma_size=$(printf 0x%x $(echo $[ $mma_end_addr - $mma_addr ]))
        echo "MMA                              $mma_addr            $mma_end_addr             $mma_size" >> $DRAM_LAYOUT
    else
        mma_end_addr=$(printf 0x%x $(echo $[ $mma_addr + $mma_size ]))
        echo "MMA                              $mma_addr            $mma_end_addr             $mma_size" >> $DRAM_LAYOUT
    fi

    rtos_addr=$mma_end_addr
    rtos_end_addr=$(printf 0x%x $(echo $[ $rtos_addr + $rtos_size ]))
    rtos_load_addr=$(printf 0x%x $(echo $[ $rtos_addr + 0x8000 ]))
    rtos_ramdisk_addr=$(printf 0x%x $(echo $[ $rtos_end_addr - $rtos_ramdisk_size - 0x1000]))
    rtos_timestamp_addr=$(printf 0x%x $(echo $[ $rtos_ramdisk_addr - $rtos_timestamp_size - 0x1000]))
    rtos_heap=$(printf 0x%x $(echo $[ $rtos_ramdisk_size + $rtos_timestamp_size + 0x400000 ]))

    dram_size_behind_rtos=$(printf 0x%x $(echo $[ $dram_base_addr + $dram_size - $rtos_end_addr ]))
    rtos_premap_cache_area_size=$(printf 0x%x $(echo $[ $dram_size - $dram_size_behind_rtos - $rtos_size ]))
    rtos_premap_noncache_area_size=$(printf 0x%x $(echo $[ $dram_size - $dram_size_behind_rtos - $rtos_size ]))

    if [[ $rtos_size -lt $rtos_heap ]]; then
        echo "set rtos_size is $rtos_size not enough, rtos_ramdisk_size will reserve $rtos_ramdisk_size!"
        exit -1
    fi

    if [ $rtos_size != "0" ]; then
        if [ $(($rtos_addr % 0x4000)) != "0" ]; then
            echo "set rtos_addr is $rtos_addr not 16K alignmen!"
            exit -1
        fi
        if [ $(($rtos_timestamp_size % 0x1000)) != "0" ]; then
            echo "set rtos_timestamp_size is $rtos_timestamp_size not 4K alignmen!"
            exit -1
        fi
        if [ $(($rtos_ramdisk_size % 0x1000)) != "0" ]; then
            echo "set rtos_ramdisk_size is $rtos_ramdisk_size not 4K alignmen!"
            exit -1
        fi
        echo "RTOS                              $rtos_addr            $rtos_end_addr              $rtos_size" >> $DRAM_LAYOUT
        eval echo "CONFIG_MMA_HEAP_ADDR = $mma_addr" >> $OUTPUT_CONFIG
        eval echo "CONFIG_MMA_HEAP_SIZE = $mma_size" >> $OUTPUT_CONFIG
        eval echo "RTOS_LOAD_ADDR = $rtos_load_addr" >> $OUTPUT_CONFIG
        eval echo "RTOS_BOOT_ENV = rtos_size=$rtos_size limit_dram_size=$dram_size no_access_size=$dram_size_behind_rtos" >> $OUTPUT_CONFIG
        eval echo "RTOS_RAMDISK_LOAD_ADDR = $rtos_ramdisk_addr" >> $OUTPUT_CONFIG
        eval echo "RTOS_RAMDISK_MEMORY_SIZE = $rtos_ramdisk_size" >> $OUTPUT_CONFIG
        eval echo "RTOS_TIMESTAMP_RSVD_ADDR = $rtos_timestamp_addr" >> $OUTPUT_CONFIG
        eval echo "RTOS_TIMESTAMP_SIZE = $rtos_timestamp_size" >> $OUTPUT_CONFIG
        eval echo "RTOS_NO_ACCESS_MEM_SIZE = $dram_size_behind_rtos" >> $OUTPUT_CONFIG
        if [ $rtos_dynamic_load_en == "y" ]; then
            sed -i 's/CONFIG_RTOS_MEM_START_VA=.*/CONFIG_RTOS_MEM_START_VA='"0xf0000000"'/g'  $RTOS_DEFCONFIG
        else
            sed -i 's/CONFIG_RTOS_MEM_START_VA=.*/CONFIG_RTOS_MEM_START_VA='"${rtos_addr}"'/g'  $RTOS_DEFCONFIG
        fi
        sed -i 's/CONFIG_RTOS_MEM_START_PA=.*/CONFIG_RTOS_MEM_START_PA='"${rtos_addr}"'/g'  $RTOS_DEFCONFIG
        sed -i 's/CONFIG_RTOS_MEMORY_SIZE=.*/CONFIG_RTOS_MEMORY_SIZE='"${rtos_size}"'/g'  $RTOS_DEFCONFIG
        sed -i 's/CONFIG_LIMIT_DRAM_SIZE=.*/CONFIG_LIMIT_DRAM_SIZE='"${dram_size}"'/g'  $RTOS_DEFCONFIG
        sed -i 's/CONFIG_PREMAP_CACHE_SIZE=.*/CONFIG_PREMAP_CACHE_SIZE='"${rtos_premap_cache_area_size}"'/g'  $RTOS_DEFCONFIG
        sed -i 's/CONFIG_PREMAP_NONCACHE_SIZE=.*/CONFIG_PREMAP_NONCACHE_SIZE='"${rtos_premap_noncache_area_size}"'/g'  $RTOS_DEFCONFIG
        earlyinit_size=$(sed -n "/^EARLYINIT_MEM_SIZE\b/p" $OUTPUT_CONFIG | awk -F' = ' '{print $2}')
        earlyinit_addr=$(printf 0x%x $(echo $[ $INITRAMFSLOADADDR - $earlyinit_size ]))
        sed -i 's/CONFIG_EARLYINIT_FW_LOAD_ADDR=.*/CONFIG_EARLYINIT_FW_LOAD_ADDR='"${earlyinit_addr}"'/g'  $RTOS_DEFCONFIG
        sed -i 's/CONFIG_EARLYINIT_FW_MEMORY_SIZE=.*/CONFIG_EARLYINIT_FW_MEMORY_SIZE='"${earlyinit_size}"'/g'  $RTOS_DEFCONFIG
   fi

    vmm_addr=$rtos_end_addr

else

    vmm_addr=$lx_end_addr
    lx_heap=$(printf 0x%x $(echo $[ $mma_size + $cma_size + $logo_size + $smf_size + $riscv_size ]))

    if [[ $lx_size -lt $lx_heap ]]; then
        echo "set lx_size is $lx_size not enough, mma_size will reserve $mma_size!"
        exit -1
    fi
    if [ $mma_size != "0" ]; then
        eval echo "KERNEL_RESERVED_MMA = mma_heap=mma_heap_name0,miu=0,sz=$mma_size mma_memblock_remove=1" >> $OUTPUT_CONFIG
    fi

    mma_addr=$(printf 0x%x $(echo $[ $lx_end_addr - $lx_heap ]))

fi

if [ $riu_recorder_size != "0" ]; then
    if [ $(($riu_recorder_size % 0x1000)) != "0" ]; then
        echo "set riu_recorder_size is $riu_recorder_size not 4K alignmen!"
        exit -1
    fi
    kernel_riu_record=riu_record=$riu_recorder_size
fi

vmm_end_addr=$(printf 0x%x $(echo $[ $vmm_addr + $vmm_size ]))
vmm_load_addr=$(printf 0x%x $(echo $[ $vmm_addr + 0x8000 ]))

if [ $vmm_size != "0" ]; then
    if [ $(($vmm_size % 0x200000)) != "0" ]; then
        echo "set vmm_size is $vmm_size not 2M alignmen!"
        exit -1
    fi
    echo "VMM                              $vmm_addr            $vmm_end_addr              $vmm_size" >> $DRAM_LAYOUT
    eval echo "VMM_LOAD_ADDR = $vmm_load_addr" >> $OUTPUT_CONFIG
    eval echo "VMM_LIMIT_MEM_SIZE = $dram_size" >> $OUTPUT_CONFIG
fi

optee_addr=$vmm_end_addr
optee_end_addr=$(printf 0x%x $(echo $[ $optee_addr + $optee_size ]))

if [ $optee_size != "0" ]; then
    if [ $(($optee_size % 0x1000)) != "0" ]; then
        echo "set optee_size is $optee_size not 4K alignmen!"
        exit -1
    fi
    echo "OPTEE                             $optee_addr            $optee_end_addr              $optee_size" >> $DRAM_LAYOUT
    OPTEE_DEFCONFIG=$PROJ_ROOT/../optee/optee_os/core/arch/arm/plat-$CHIP/conf.mk
    sed -i 's/CFG_TZDRAM_START ?= .*/CFG_TZDRAM_START ?= '"${optee_addr}"'/g'  $OPTEE_DEFCONFIG
    sed -i 's/CFG_TZDRAM_SIZE ?= .*/CFG_TZDRAM_SIZE ?= '"${optee_size}"'/g'  $OPTEE_DEFCONFIG
fi

tfa_addr=$optee_end_addr
tfa_end_addr=$(printf 0x%x $(echo $[ $tfa_addr + $tfa_size ]))

if [ $tfa_size != "0" ]; then
    if [ $(($tfa_size % 0x1000)) != "0" ]; then
        echo "set tfa_size is $tfa_size not 4K alignmen!"
        exit -1
    fi
    echo "TFA                                 $tfa_addr             $tfa_end_addr             $tfa_size" >> $DRAM_LAYOUT
fi

if [ $tfa_end_addr != $dram_end_addr ]; then
    echo "dram layout err tfa_end_addr $tfa_end_addr != dram_end_addr $dram_end_addr !"
    exit -1
fi

kernel_lx_mem=$(sed -n "/^KERNEL_LX_MEM\b/p" $OUTPUT_CONFIG | awk -F' = ' '{print $2}')
kernel_reserved_mma=$(sed -n "/^KERNEL_RESERVED_MMA\b/p" $OUTPUT_CONFIG | awk -F' = ' '{print $2}')
kernel_reserved_cma=$(sed -n "/^KERNEL_RESERVED_CMA\b/p" $OUTPUT_CONFIG | awk -F' = ' '{print $2}')
kernel_reserved_logo=$(sed -n "/^KERNEL_RESERVED_LOGO\b/p" $OUTPUT_CONFIG | awk -F' = ' '{print $2}')
kernel_reserved_smf=$(sed -n "/^KERNEL_RESERVED_SMF\b/p" $OUTPUT_CONFIG | awk -F' = ' '{print $2}')
kernel_reserved_riscv=$(sed -n "/^KERNEL_RESERVED_RISCV\b/p" $OUTPUT_CONFIG | awk -F' = ' '{print $2}')

if [ -n "$kernel_reserved_smf" ]; then
    if [ "$kernel_reserved_env" == "mmap_reserved=" ]; then
        kernel_reserved_env="$kernel_reserved_smf "
    else
        kernel_reserved_env+="$kernel_reserved_smf "
    fi
fi

if [ -n "$kernel_reserved_riscv" ]; then
    if [ "$kernel_reserved_env" == "mmap_reserved=" ]; then
        kernel_reserved_env="$kernel_reserved_riscv "
    else
        kernel_reserved_env+="$kernel_reserved_riscv "
    fi
fi

if [ -n "$kernel_reserved_logo" ]; then
    if [ "$kernel_reserved_env" == "mmap_reserved=" ]; then
        kernel_reserved_env="$kernel_reserved_logo"
    else
        kernel_reserved_env+="$kernel_reserved_logo"
    fi
fi

eval echo "KERNEL_BOOT_ENV = $kernel_lx_mem $kernel_reserved_mma $kernel_reserved_cma  $kernel_riu_record" >> $OUTPUT_CONFIG

dual_os=$(sed -n "/^DUAL_OS\b/p" $OUTPUT_CONFIG | awk -F' = ' '{print $2}')
if [ "${dual_os}" == "on" ]; then
    eval echo "KERNEL_ONLY_LX_MEM = LX_MEM=$dram_size" >> $OUTPUT_CONFIG
    eval echo "KERNEL_ONLY_RESERVED_MMA = mma_heap=mma_heap_name0,miu=0,sz=$mma_size mma_memblock_remove=1" >> $OUTPUT_CONFIG
    kernel_only_lx_mem=$(sed -n "/^KERNEL_ONLY_LX_MEM\b/p" $OUTPUT_CONFIG | awk -F' = ' '{print $2}')
    kernel_only_reserved_mma=$(sed -n "/^KERNEL_ONLY_RESERVED_MMA\b/p" $OUTPUT_CONFIG | awk -F' = ' '{print $2}')
    eval echo "KERNEL_ONLY_BOOT_ENV = $kernel_only_lx_mem $kernel_only_reserved_mma $kernel_reserved_cma  $kernel_riu_record" >> $OUTPUT_CONFIG
fi

if [ "$kernel_reserved_env" != "mmap_reserved=" ]; then
    sed -i "s/KERNEL_BOOT_ENV.*/& \$(KERNEL_RESERVED_ENV)/g" $OUTPUT_CONFIG
    echo "KERNEL_RESERVED_ENV = $kernel_reserved_env" >> $OUTPUT_CONFIG
fi

echo "ALKAID_MHAL_UT = $ALKAID_MHAL_UT" >> $OUTPUT_CONFIG

check_param_empty_and_delete DOWNLOADADDR KERNELBOOTADDR INITRAMFSLOADADDR SPLIT_EACH_FILE_SIZE

cat $OUTPUT_CONFIG
