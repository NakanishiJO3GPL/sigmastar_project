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
parse_file=${srctree}/dmv_parse.txt
log_file=${srctree}/dm_verity.log
config_file=${srctree}/../dm_verity.config

# dmverity can disable superblock by command "--no-superblock"
# if special_cmd include "--no-superblock",superblock will be set to zero
superblock=1

if [  -z ${1} ]; then
    echo "usage:"
    echo "$0 <file_name> <rootfs> <rootfs suffix> <rootfs packet way>"
    exit
fi

function clear_file() {
    if [  -e $parse_file ]; then
        rm $parse_file
    fi

    if [  -e $log_file ]; then
        rm $log_file
    fi
}

function update_verity() {

    # parse ${log_file},and write to $parse_file
    while IFS= read -r line
        do
            if [[ $line == \#* ]]; then
                continue
            fi
            # parse data
            if [[ $line == *:* ]]; then
                key=$(echo "$line" | awk -F':' '{print $1}' | awk '{$1=$1};1' | tr ' ' '_')
                value=$(echo "$line" | awk -F':' '{print $2}' | awk '{$1=$1};1')
                echo "${1}_${key}=${value}" >> "${parse_file}"
                #echo "${key} = $value"
                declare -r "$key=$value"
            fi
    done < "${log_file}"


    size=$(stat -c %s "$2")

    # num_sectors = file_size/512 <sectors长度固定为512>
    Num_sectors=$((size / 512))

    # 
    if [[ ${4} == rootfs_middle ]]; then
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

    echo "${1}_Num_sectors=${Num_sectors}" >> "$parse_file"
    echo "${1}_Hash_start_block=${Hash_start_block}" >> "$parse_file"

    # update ${parse_file} to ${config_file}
    while IFS='=' read -r key value
        do
            sed -i "s/^${key}=.*/${key}=${value}/" "${config_file}"
    done < "${parse_file}"

}

function generate_hash_device()
{
    # declare keyword
    while IFS='=' read -r key value
        do
        # Skip lines that start with #
        if [[ $key == \#* ||  -z $key ]]; then
            continue
        fi

        # Remove starting and ending Spaces
        key=$(echo "$key" | awk '{$1=$1};1')
        value=$(echo "$value" | awk '{$1=$1};1')

        if [[ ${key} == ${1}* ]]; then
            trimmed_key="${key#${1}_}"
            #echo "trimmed_key = $trimmed_key"
            declare -r "$trimmed_key=$value"
        fi
    done < "${config_file}"

    if [[ ! -z $special_cmd ]]; then
        cmd_special=${special_cmd//\"/}
        if [[ $special_cmd == *"--no-superblock"* ]]; then
            superblock=0
        else
            superblock=1
        fi
    fi

    if [[ ! -z $Data_block_size && $Data_block_size != 0 ]]; then
        cmd_Data_block_size="--data-block-size=$Data_block_size"
    fi

    if [[ ! -z $Hash_block_size && $Hash_block_size != 0 ]]; then
        cmd_hash_block_size="--hash-block-size=$Hash_block_size"
    fi

    if [[  -z $Hash_algorithm ]]; then
        echo "Hash_algorithm is null , def use sha256"
        Hash_alg="sha256"
    else
        Hash_alg=$Hash_algorithm
    fi
    
    echo "Data_block_size = $Data_block_size"
    echo "Hash_block_size = $Hash_block_size"
    echo "start_sector = $start_sector"
    echo "UUID = $UUID"
    echo "Hash_type = $Hash_type"
    echo "Data_blocks = $Data_blocks"
    echo "Hash_alg = $Hash_alg"
    echo "Salt = $Salt"
    echo "Root_hash = $Root_hash"
    echo "hash_start_block = $hash_start_block"
    echo " "
    log_show_save "# begin to generate hash device"
    log_show_save "veritysetup format $2 $srctree/${1}_hash_device.bin $cmd_Data_block_size $cmd_hash_block_size --hash=$Hash_alg $cmd_salt $cmd_uuid $cmd_special"

    #Usage: veritysetup [-?v] [-?|--help] [--usage] [--version] [-v|--verbose] [--debug] [--no-superblock] [--format=number] [--data-block-size=bytes] [--hash-block-size=bytes] [--fec-roots=bytes]
    #        [--data-blocks=blocks] [--fec-device=path] [--hash-offset=bytes] [--fec-offset=bytes] [-h|--hash=string] [-s|--salt=hex string] [--uuid=STRING] [--restart-on-corruption] [--ignore-corruption]
    #        [--ignore-zero-blocks] [OPTION...] <action> <action-specific>
    veritysetup format $2 $srctree/${1}_hash_device.bin $cmd_Data_block_size $cmd_hash_block_size --hash=$Hash_alg $cmd_salt $cmd_uuid $cmd_special > $log_file
    cat $log_file

    cp ${1}_hash_device.bin $2$3

    if [[  -z $Start_sector ]]; then
        # default set start sector to zero
        echo "default set start sector to zero"
        echo "Start_sector:0" >> "$log_file"
    #else
    #    echo "Start_sector=${Start_sector}" >> "$log_file"
    fi
}


# $1 file name, such as "rootfs"
# $2 input image name.include path
# $3 Output image suffix
# $4 rootfs packet way
function do_generate_hash_device()
{
    clear_file
    echo " "
    echo [hash_device generate]

    while IFS='=' read -r key value
    do
        if [[ ${key} == ${1}_Root_hash ]]; then
            generate_hash_device $1 $2 $3 $4
            update_verity $1 $2 $3 $4
        fi
    done < "${config_file}"
    echo " "
    clear_file
}

popd > /dev/null

