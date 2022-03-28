#!/usr/bin/env python3
import sys
import argparse
import ipaddress

parser = argparse.ArgumentParser(description="Calculate subnets assigned to a number of OpenVPN daemons.")
parser.add_argument('-a', '--address-space', type=str, metavar='x.x.x.x/y', help='VPN address space', required=True)
parser.add_argument('-n', '--subnets', metavar='N', type=int, help='Number of subnets', required=False, default=2)
parser.add_argument('-b', '--batch', action='store_true', help="Produce script consumable output", required=False)

args = parser.parse_args()

i = 1

for subnet in list(ipaddress.IPv4Network(args.address_space).subnets(int.bit_length(args.subnets - 1))):
    # Calculate i-th subnet
    if args.batch:
        print (subnet.network_address.compressed + " " + subnet.netmask.compressed + " " + str(list(subnet.hosts())[0]))
    else:
        print ('Subnet #' + str(i) + ": " + subnet.with_netmask + " or " + str(subnet.with_prefixlen) + " server host: " + str(list(subnet.hosts())[0]))
    i += 1
