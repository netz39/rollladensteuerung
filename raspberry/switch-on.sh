#!/bin/bash

# INT
gpio mode 0 tri

# Power
gpio mode 2 out
gpio mode 3 out

gpio write 2 1
gpio write 3 1
