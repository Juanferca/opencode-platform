#!/usr/bin/env bash

set -euo pipefail

echo "========================================"
echo " OpenCode Platform - Health Check"
echo "========================================"

echo
echo "[HOST]"
hostnamectl | grep "Static hostname"

echo
echo "[UPTIME]"
uptime

echo
echo "[MEMORY]"
free -h

echo
echo "[DISK]"
df -h /

echo
echo "[DOCKER]"
docker ps --format "table {{.Names}}\t{{.Status}}"

echo
echo "[DOCKER USAGE]"
docker system df
