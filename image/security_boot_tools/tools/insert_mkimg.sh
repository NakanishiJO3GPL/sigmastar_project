srctree=$(dirname "$0")
pushd $srctree > /dev/null

source $srctree/log.sh
tools_path=$srctree
main_path=$srctree/..

enable_log=1
#$1 image_name
#$2 rsakeylen
#$3 which rsakey
echo insert_mkimg
if [[ -n $4 ]]; then
    IV="--IV=$main_path/aeskey/$4"
fi

if [[ $enable_log == 1 ]]; then
    log_show_save "$tools_path/key_proc.py --insert --rsa=$main_path/rsa$2/$3 $IV -f $1 $NULL_LOG"
fi
$tools_path/key_proc.py --insert --rsa=$main_path/rsa$2/$3 $IV -f $1 $NULL_LOG