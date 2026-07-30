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

log_file=dm_verity.log

packet_way=rootfs_middle
tools_path=$srctree


# $1: file
# $2: Hash_block_size
function fill_to_align()
{
    local file="$1"
    local min_size=1024  # 1KB
    block_size=$2

    if [[ ${packet_way} == rootfs_middle ]]; then
        if [[ $block_size -gt 1024 ]]; then
            aligned_size=$block_size
        else
            aligned_size=1024
            remainder=$((block_size % 1024))
            if [ $remainder -ne 0 ]; then
                aligned_size=$((aligned_size + 1024 - remainder))
            fi
        fi
        min_size=$aligned_size
    else
        min_size=1024
    fi

    # get file size
    local size=$(stat -c "%s" "$file")

    # check file size
    if [[ $size -lt $min_size ]]; then
        local padding=$((min_size - size))
        echo "# append data to $file, need align to $min_size(block_size)"
        echo "dd if=/dev/zero bs=1 count="$padding" >> "$file""
        dd if=/dev/zero bs=1 count="$padding" >> "$file"
    fi
}


function do_dmverity()
{
    if [[ -z ${1} || ${1} == "-h" || ${1} == "--help" ]]; then
        echo " "
        echo "usage:"
        echo "    $0 [origin rootfs binary] [private key] <output_name>"
        echo " "
        exit
    fi;

    #clear_file
    echo " "
    echo "[hash_device generate]"

    Hash_alg=sha256
    cmd_special="--debug --no-superblock"

    echo " "
    echo "veritysetup format $1 $srctree/${1}.hash $cmd_Data_block_size $cmd_hash_block_size --hash=$Hash_alg $cmd_salt $cmd_uuid $cmd_special"
    veritysetup format $1 $srctree/${1}.hash $cmd_Data_block_size $cmd_hash_block_size --hash=$Hash_alg $cmd_salt $cmd_uuid $cmd_special > $log_file
    cat $log_file


    while IFS= read -r line
        do
            if [[ $line == \#* ]]; then
                continue
            fi
            # parse data
            if [[ $line == *:* ]]; then
                key=$(echo "$line" | awk -F':' '{print $1}' | awk '{$1=$1};1' | tr ' ' '_')
                value=$(echo "$line" | awk -F':' '{print $2}' | awk '{$1=$1};1')
                echo "${key} = $value"
                declare -r "$key=$value"
            fi
    done < "${log_file}"

    Start_sector=0
    size=$(stat -c %s "$1")
    # num_sectors = file_size/512 <sectors长度固定为512>
    Num_sectors=$((size / 512))
    if [[ ${packet_way} == rootfs_middle ]]; then
        if [ $Hash_block_size -gt 1024 ]; then
            aligned_size=$Hash_block_size
        else
            aligned_size=1024
            remainder=$((Hash_block_size % 1024))
            if [ $remainder -ne 0 ]; then
                aligned_size=$((aligned_size + 1024 - remainder))
            fi
        fi
        filesize=$((size + aligned_size))
    fi

    # num_data_blocks = file_size/Hash_block_size + superblock
    Hash_start_block=$((filesize / Hash_block_size + superblock))

    echo " "
    echo "[append data generate]"
    echo "$tools_path/key_proc.py --append --append_version=1 --dm_verity=$UUID,$Start_sector,$Num_sectors,$Data_block_size,$Hash_block_size,$Data_blocks,$Hash_start_block,$Hash_algorithm,$Root_hash,$Salt -f $1"
    $tools_path/key_proc.py --append --append_version=1 --dm_verity=$UUID,$Start_sector,$Num_sectors,$Data_block_size,$Hash_block_size,$Data_blocks,$Hash_start_block,$Hash_algorithm,$Root_hash,$Salt -f $1

    file_directory=$(dirname "$1")
    file_name=$(basename "$1" | cut -f1 -d'.')
    file_extension=$(basename "$1" | cut -f2- -d'.')

    echo "$tools_path/key_proc.py --sign --rsa=$2 -f ${file_name}.append.${file_extension}"
    $tools_path/key_proc.py --sign --rsa=$2 -f $file_directory/${file_name}.append.${file_extension}
    fill_to_align $file_directory/${file_name}.append.sig.${file_extension} $Hash_block_size

    echo " "
    echo "[final data generate]"
    # cat all file to binary
    if [ -n "$3" ]; then
        cat ${1} $file_directory/${file_name}.append.sig.${file_extension} $srctree/${1}.hash > $3
        echo "cat ${1} $file_directory/${file_name}.append.sig.${file_extension} $srctree/${1}.hash > $3"
        last_name=$3
    else
        cat ${1} $file_directory/${file_name}.append.sig.${file_extension} $srctree/${1}.hash > ${1}.final
        echo "cat ${1} $file_directory/${file_name}.append.sig.${file_extension} $srctree/${1}.hash > ${1}.final"
        last_name=${1}.final
    fi

    echo " "
    echo "[done] last file is $last_name"
    echo " "
}

# $1 origin rootfs path+name
# $2 private key
# $3 output name
do_dmverity $1 $2 $3

popd > /dev/null