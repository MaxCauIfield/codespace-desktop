#!/bin/bash
sudo tailscaled --tun=userspace-networking --socks5-server=localhost:1055 &
sleep 3
sudo tailscale up
