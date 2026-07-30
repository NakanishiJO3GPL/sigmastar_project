#!/usr/bin/python
from __future__ import print_function, division, absolute_import

import os
import sys
import argparse
import binascii

def str_hex(s):
    if sys.version_info[0] >= 3:
        return binascii.hexlify(s).decode('ascii')
    return binascii.hexlify(s)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='check load addr from image head')
    parser.add_argument("--infile", help="in")
    parser.add_argument("--out", help="out")
    args = parser.parse_args()

    with open(args.infile, "rb") as infile:
        infile.seek(12)
        ih_size = binascii.hexlify(infile.read(4)).decode('ascii')
        ih_load = binascii.hexlify(infile.read(4)).decode('ascii')
        
        if int(ih_load, 16) < 0x20000000:
            sys.exit(0)
            
        ih_load_end = hex(int(ih_load, 16) + int(ih_size, 16))
        
        with open(args.out, "a+") as out:
            out.write(args.infile + "\n")
            out.write("0x" + ih_load + "-" + ih_load_end + "\n")
