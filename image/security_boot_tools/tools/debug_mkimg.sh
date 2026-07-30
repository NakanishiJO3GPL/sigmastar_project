srctree=$(dirname "$0")
pushd $srctree > /dev/null

source $srctree/log.sh
tools_path=$srctree
main_path=$srctree/..

enable_log=1
cid=0

#$1 input image
#$2 output image
#$3 aes encrypt flag
if [[ $sw_debug != 1 && $sw_debug != 2 && $sw_debug != 3 ]]; then
    #for normal boot used sig image
    #rsa2048, sw_debug=4
    #rsa4096, sw_debug=5
    sw_debug=$((rsalen/2048+3))

fi

if [[ $enable_log == 1 ]]; then
    log_show_save "$tools_path/add_ipl_header.py $1 $2 $cid $sw_debug $4 $3 $NULL_LOG"
fi
    $tools_path/add_ipl_header.py $1 $2 $cid $sw_debug $4 $3 $NULL_LOG
