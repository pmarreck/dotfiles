#!/usr/bin/env bash

# Simple script to debug IPv6 address detection
echo "=== Raw output from ip -6 addr show ==="
ip -6 addr show

echo -e "\n=== Testing for global addresses (2000::/3) ==="
ip -6 addr show | awk '/inet6/ && /global/ && $2 ~ /^2/ {print "Found global:", $2}'

echo -e "\n=== Testing for ULA addresses (fd00::/8) ==="
ip -6 addr show | awk '/inet6/ && /global/ && $2 ~ /^fd/ {print "Found ULA:", $2}'

echo -e "\n=== Testing for link-local addresses (fe80::/10) ==="
ip -6 addr show | awk '/inet6/ && /link/ && $2 !~ /::1/ {print "Found link-local:", $2}'

echo -e "\n=== Testing with simpler pattern for ULA ==="
ip -6 addr show | grep "inet6" | grep "fd" | awk '{print "Simple ULA match:", $2}'

echo -e "\n=== Raw second field from inet6 lines ==="
ip -6 addr show | grep "inet6" | awk '{print "Raw field 2:", $2}'
