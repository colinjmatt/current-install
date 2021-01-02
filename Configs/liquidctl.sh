#!/bin/bash
liquidctl initialize all

liquidctl --match kraken set pump speed 20 60 40 100
liquidctl --match kraken set fan speed  20 25  30 35  40 50  45 75  55 100
liquidctl set sync color fixed ff0000
