#!/usr/bin/python
from __future__ import print_function, division, absolute_import

import os
import sys
import argparse
import binascii

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='check load addr from image head')
    parser.add_argument("--infile", help="in")
    parser.add_argument("--uboot", help="uboot")
    parser.add_argument("--lxaddr", help="lxaddr")
    args = parser.parse_args()

    with open(args.infile, "r") as infile:
        line = infile.readline()
        with open(args.uboot, "rb") as uboot:
            uboot.seek(16)
            uboot_load = binascii.hexlify(uboot.read(4)).decode('ascii')
            uboot_run_end = hex(int(uboot_load, 16) + 0x100000)

        i = 0
        variablesold = None
        while line:
            line = line.strip()
            variables = line.split('-')
            line = infile.readline()

            if i > 1:
                if variables[0] < variablesold[1]:
                    print("check load addr fail, load addr is over write")
                    sys.exit(-1)
            variablesold = variables
            i = i + 1
