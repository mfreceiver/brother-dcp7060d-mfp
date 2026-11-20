#!/bin/sh
mkdir -p /var/run/avahi-daemon
sleep 3
exec airsaned --hotplug=true --network-hotplug=true
