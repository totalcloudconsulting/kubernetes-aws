#!/bin/bash

iptables -t nat -A POSTROUTING -s 10.8.3.0/24 -o eth0 -j MASQUERADE
echo 1 > /proc/sys/net/ipv4/ip_forward