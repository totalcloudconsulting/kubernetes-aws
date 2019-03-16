#!/bin/bash

main_interface=`ip r sh | grep default | awk '{print $5}'`

iptables -t nat -A POSTROUTING -s 10.8.3.0/24 -o ${main_interface} -j MASQUERADE
echo 1 > /proc/sys/net/ipv4/ip_forward
