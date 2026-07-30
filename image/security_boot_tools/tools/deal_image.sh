#
# Copyright (c) [2019~2020] SigmaStar Technology.
#
#
# This software is licensed under the terms of the GNU General Public
# License version 2, as published by the Free Software Foundation, and
# may be copied, distributed, and modified under those terms.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License version 2 for more details.
#

#!/bin/sh

srctree=$(dirname "$0")

pushd $srctree > /dev/null

source $srctree/log.sh
source $srctree/../sign_image.config

#ALL_OS_NAME="tee" "u-boot" "sigmastar-rtos" "sigmastar-hyp" "linux"
IH_OS_LINUX=$(printf "%02x" 5)
IH_OS_U_BOOT=$(printf "%x" 17)
IH_OS_TEE=$(printf "%x" 26)
IH_OS_SS_RTOS=$(printf "%x" 48)
IH_OS_SS_HYPERVISOR=$(printf "%x" 49)

function get_image_os() {
    case "$1" in
    "$IH_OS_LINUX")
        os_name="-O linux"
        ;;
    "$IH_OS_U_BOOT")
        os_name="-O u-boot"
        ;;
    "$IH_OS_TEE")
        os_name="-O tee"
        ;;
    "$IH_OS_SS_RTOS")
        os_name="-O sigmastar-rtos"
        ;;
    "$IH_OS_SS_HYPERVISOR")
        os_name="-O sigmastar-hyp"
        ;;
    *)
        ;;
    esac

    echo $os_name
}

# $1 sz uImage.sz
# $2 output unsz image header
# $3 payload
function mk_unsz_image() {
    log_save "# do sz decompression"
    log_save "# Separate uImage header and valid data .get header [$2] and payload [$1_text.sz]"
    log_save "dd if=$1 of=$1_text.sz bs=1 skip=64 ; dd if=$1 of=$2 bs=64 count=1"
    log_save "# decompression payload data. get [$3]"
    log_save "$srctree/unsz/szrestore $1_text.sz $1.xz;$srctree/unsz/szdec $1.xz $3"

    dd if=$1 of=$1_text.sz bs=1 skip=64 && \
    dd if=$1 of=$2 bs=64 count=1 && \
    $srctree/unsz/szrestore $1_text.sz $1.xz && \
    $srctree/unsz/szdec $1.xz $3
    log_save ""
}

# $1 lz4 uImage.lz4
# $2 output unlz4 image header
# $3 payload
function mk_unlz4_image() {
    log_save "# do lz4 decompression"
    log_save "# Separate uImage header and valid data .get header [$2] and payload [$1_text.lz4]"
    log_save "dd if=$1 of=$1_text.lz4 bs=1 skip=64 ; dd if=$1 of=$2 bs=64 count=1"
    log_save "# decompression payload data. get [$3]"
    log_save "lz4 -d $1_text.lz4 $3"

    dd if=$1 of=$1_text.lz4 bs=1 skip=64 && \
    dd if=$1 of=$2 bs=64 count=1 && \
    lz4 -d $1_text.lz4 $3
    log_save ""
}

# $1 header_name
# $2 noraml image name which prepare to sz
# $3 the final file
function create_sz_image() {
    ld_addr=$(hexdump -e '1/4 "%08x0x"' -s 16 -n 4 $1 | tac -rs ..)
    ep_addr=$(hexdump -e '1/4 "%08x0x"' -s 20 -n 4 $1 | tac -rs ..)
    data_size=$(hexdump -e '1/4 "%08x0x"' -s 12 -n 4 $1 | tac -rs ..)
    ih_os=$(hexdump -e '1/1 "%02x"' -s 28 -n 1 $1)
    ih_arch=$(hexdump -e '1/1 "%02x"' -s 29 -n 1 $1)
    ih_type=$(hexdump -e '1/1 "%02x"' -s 30 -n 1 $1)
    ih_comp=$(hexdump -e '1/1 "%02x"' -s 31 -n 1 $1)
    result=$(hexdump -v -e '/1 "%_p"' -s 32 -n 32 $1)
    version="${result%%.*}"

    echo "version:       $version"
    echo "Load Addr:     $ld_addr"
    echo "Entry Addr:    $ep_addr"
    echo "Data_Size:     $data_size"
    echo "ih_os:         $ih_os"
    echo "ih_arch:       $ih_arch"
    echo "ih_type:       $ih_type"
    echo "ih_comp:       $ih_comp"

    ih_os=$(get_image_os $ih_os)

    log_save "# do sz compress"
    log_save "header_name=$1"
    log_save "${srctree}/sz/sstar_sz.sh -d $2 -b 4"
    log_save "#[$2.sz] add header and generate the final file [$3]"
    log_save 'ld_addr=$(hexdump -e '\''1/4 "%02x0x"'\'' -s 16 -n 4 $header_name | tac -rs ..)'
    log_save 'ep_addr=$(hexdump -e '\''1/4 "%02x0x"'\'' -s 20 -n 4 $header_name | tac -rs ..)'
    log_save 'result=$(hexdump -v -e '\''/1 "%_p"'\'' -s 32 -n 32 $header_name)'
    log_save 'version="${result%%.*}"'
    log_save "${srctree}/mkimage -A arm $ih_os"' -C lzma2 -a "$ld_addr" -e "$ep_addr" -n "$version" -d'" $2.sz $3"

    ${srctree}/sz/sstar_sz.sh -d $2 -b 4 &&\
    ${srctree}/mkimage -A arm $ih_os -C lzma2 -a "$ld_addr" -e "$ep_addr" -n "$version" -d $2.sz $3
}

# $1 header_name
# $2 noraml image name which prepare to lz4
# $3 the final file
function create_lz4_image() {
    ld_addr=$(hexdump -e '1/4 "%08x0x"' -s 16 -n 4 $1 | tac -rs ..)
    ep_addr=$(hexdump -e '1/4 "%08x0x"' -s 20 -n 4 $1 | tac -rs ..)
    data_size=$(hexdump -e '1/4 "%08x0x"' -s 12 -n 4 $1 | tac -rs ..)
    ih_os=$(hexdump -e '1/1 "%02x"' -s 28 -n 1 $1)
    ih_arch=$(hexdump -e '1/1 "%02x"' -s 29 -n 1 $1)
    ih_type=$(hexdump -e '1/1 "%02x"' -s 30 -n 1 $1)
    ih_comp=$(hexdump -e '1/1 "%02x"' -s 31 -n 1 $1)
    result=$(hexdump -v -e '/1 "%_p"' -s 32 -n 32 $1)
    version="${result%%.*}"

    echo "version:       $version"
    echo "Load Addr:     $ld_addr"
    echo "Entry Addr:    $ep_addr"
    echo "Data_Size:     $data_size"
    echo "ih_os:         $ih_os"
    echo "ih_arch:       $ih_arch"
    echo "ih_type:       $ih_type"
    echo "ih_comp:       $ih_comp"

    ih_os=$(get_image_os $ih_os)

    log_save "# do lz4 compress"
    log_save "header_name=$1"
    log_save "lz4 -f -9 $2 $2.lz4"
    log_save "#[$2.sz] add header and generate the final file [$3]"
    log_save 'ld_addr=$(hexdump -e '\''1/4 "%02x0x"'\'' -s 16 -n 4 $header_name | tac -rs ..)'
    log_save 'ep_addr=$(hexdump -e '\''1/4 "%02x0x"'\'' -s 20 -n 4 $header_name | tac -rs ..)'
    log_save 'result=$(hexdump -v -e '\''/1 "%_p"'\'' -s 32 -n 32 $header_name)'
    log_save 'version="${result%%.*}"'
    log_save "${srctree}/mkimage -A arm $ih_os -C lz4 -a "$ld_addr" -e "$ep_addr" -n "$version" -d $2.lz4 $3"

    lz4 -f -9 $2 $2.lz4
    ${srctree}/mkimage -A arm $ih_os -C lz4 -a "$ld_addr" -e "$ep_addr" -n "$version" -d $2.lz4 $3
}

function image_getname() {
    filename=$1
    insert_name=null
    case "$2" in
    "signusb")
        insert_name=.cut.append.sig
        ;;
    "sign")
        insert_name=.sig
        ;;
    "aes")
        insert_name=.aes
        ;;
    "cipher")
        insert_name=.cipher
        ;;
    "debug")
        insert_name=2
        ;;
    "append")
        insert_name=.append
        ;;
    *)
        echo "ERROR"
        ;;
    esac

    if [[ $1 == *.* ]]; then
        extension="${filename##*.}"
        basename="${filename%.*}"
        IMAGE_NAME="${basename}${insert_name}.${extension}"
    else
        IMAGE_NAME="${filename}${insert_name}"
    fi
    echo $IMAGE_NAME
}

UIMAGE_HEADER_MAGIC=27051956
SZ_COMPRESS=0b
LZ4_COMPRESS=05
function distribute_image() {
    input_image=$1
    suffix=$2
    image_type=$3
    usb=$4

    current_image=$input_image
    ih_magic=$(hexdump -e '4/1 "%02x"' -s 0 -n 4 $input_image)
    ih_comp=$(hexdump -e '1/1 "%02x"' -s 31 -n 1 $input_image)

    # skip cis
    if [[ $image_type == cis ]]; then
        cp $input_image $input_image$suffix
        return 0
    fi

    log_save "# begin to sign $image_type image"
    # mk_unsz_image
    # spixz still need to be add

    # i6dw sz uImage
    # 1.decompress if need
    # for *.sz image
    if [ $ih_magic == $UIMAGE_HEADER_MAGIC ] && [ $ih_comp == $SZ_COMPRESS ];then
        echo "sz decompress"
        mk_unsz_image $current_image $current_image.header $current_image.payload
        compress_header=$current_image.header
        current_image=$current_image.payload
    # for ipl_cust.lz4
    elif [ $ih_magic == $UIMAGE_HEADER_MAGIC ] && [ $ih_comp == $LZ4_COMPRESS ] && [ $image_type == ipl_cust ];then
        echo "lz4 decompress"
        mk_unlz4_image $current_image $current_image.header $current_image.payload
        compress_header=$current_image.header
        current_image=$current_image.payload
    fi

    # 2. insert nkey & add debug heaer
    if [ $image_type == ipl ];then
        source $srctree/insert_mkimg.sh $current_image $rsalen public-cust.pem $ipl_IV
        current_image=$(image_getname $current_image cipher)
        debug_name=$(image_getname $current_image debug)
        source $srctree/debug_mkimg.sh  $current_image $debug_name 0 $ipl_abk
        current_image=$debug_name
    elif [ $image_type == ipl_cust ];then
        source $srctree/insert_mkimg.sh $current_image $rsalen public-image.pem $ipl_cust_IV
        current_image=$(image_getname $current_image cipher)
        debug_name=$(image_getname $current_image debug)
        source $srctree/debug_mkimg.sh  $current_image $debug_name 0 $ipl_cust_abk
        current_image=$debug_name
    fi

    # 3.compress if need (only ipl_cust.lz4)
    if [ $ih_magic == $UIMAGE_HEADER_MAGIC ] && [ $ih_comp == $LZ4_COMPRESS ] && [ $image_type == ipl_cust ];then
        # log_save "create_lz4_image $compress_header $current_image $current_image.sz"
        create_lz4_image $compress_header $current_image $current_image.comp
        current_image=$current_image.comp
    fi

    # 4. encrypt(optional) & append(optional) & add signature(must)
    # log_save "$srctree/sign_img.sh $current_image ".sigout" $image_type $usb"
    $srctree/sign_img.sh $current_image ".sigout" $image_type $usb
    current_image=$current_image.sigout

    echo "[sign_img]current_image = $current_image"
    # 5.add_sbot_heaer if need
    if [[ $current_image == */IPL_CUST.*lz4* ]] || [[ $current_image != */IPL* && $current_image != */rootfs* ]]; then
        echo "add sbot header"
        log_save "${srctree}/mkimage -A arm -C none -a 0 -e 0 -n "sbot" -d $current_image $current_image.sbot"
        ${srctree}/mkimage -A arm -C none -a 0 -e 0 -n "sbot" -d $current_image $current_image.sbot
        current_image=$current_image.sbot
    fi

    # 6.compress if need (only for *.sz image)
    if [ $ih_magic == $UIMAGE_HEADER_MAGIC ] && [ $ih_comp == $SZ_COMPRESS ];then
        # log_save "create_sz_image $compress_header $current_image $current_image.sz"
        create_sz_image $compress_header $current_image $current_image.comp
        current_image=$current_image.comp
    fi

    # 7.get result image
    log_save "mv $current_image $input_image$suffix"
    cp $current_image $input_image$suffix
    current_image=$input_image$suffix

    log_save ''
    log_save ''
}

#$1 input image name.include path
#$2 Output image suffix
#$3 image type
#$4 usb or not, or dmverity type, depends on keyword
distribute_image $1 $2 $3 $4

popd > /dev/null

