#!/usr/bin/python

import  os, sys, argparse, binascii

def parser_region(start, size, name, outfile):
    out = open(outfile, "a+")
    ih_load = start
    ih_load_end = hex(int(start, 0)+int(size, 0))
    out.write(name + "\n")
    out.write(ih_load + "-" + ih_load_end + "\n")
    out.close()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='check load addr from image head')
    parser.add_argument("--out", help="out")
    parser.add_argument("--start", help="start")
    parser.add_argument("--size", help="size")
    parser.add_argument("--name", help="name")
    args=parser.parse_args()

    if args.out:
        parser_region(args.start, args.size, args.name, args.out)
    