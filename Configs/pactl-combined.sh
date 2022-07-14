#!/bin/bash
pactl load-module module-combine-sink

while :;
do
  pactl set-default-sink combined;
  sleep 1;
done
