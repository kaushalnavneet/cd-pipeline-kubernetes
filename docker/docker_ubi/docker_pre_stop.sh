#!/bin/bash
echo "Shutting down.." > /proc/1/fd/1

jobs=$(docker ps | tail -n+2)
echo "found jobs=${jobs}" > /proc/1/fd/1

while [[ ! -z "${jobs}" ]]; do
    sleep 5
    jobs=$(docker ps | tail -n+2)
    echo "inside jobs=${jobs}" > /proc/1/fd/1
done

echo "all done" > /proc/1/fd/1
jobs=$(docker ps | tail -n+2)
echo "outside jobs=${jobs}" > /proc/1/fd/1