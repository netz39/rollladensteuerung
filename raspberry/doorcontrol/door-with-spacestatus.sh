#!/bin/bash

# Lock the door if SpaceTime is not active
# 30 seconds after it is unlocked

function wait_for_status {
	st=$1
	s=""
	
	while [ "$s" != "$st" ]; do
		s=$(./door-status.sh)
		echo $s
		sleep 1s
	done
}

function space_is_open {
	json=$(curl -s https://spaceapi.n39.eu/json)
	isopen=$(echo $json | jq .state.open)
	
	echo "$isopen"
}

function i2c_set {
	local addr=$1
	local cmd=$2

	ret=""
	while [[ "$ret" != "0x01" ]]; do
		ret=$(/usr/sbin/i2cget -y 1 $addr $cmd)
		echo $ret
	done
}

TIMEOUT=30
DELAY=5

logger -t lockfailsafe SpaceTime observation restarted with timeout ${TIMEOUT}s and a delay of ${DELAY}s.

while [[ true ]]; do
	# check the door status
	s=$(./door-status.sh)
	echo "Door state: $s"
	
	# if unlocked
	if [ "$s" == "0x0d" ]; then
		echo "Door is unlocked."
		logger -t lockfailsafe SpaceTime observation engaged.
	
		# check space status
		isopen=''
		timeout=$TIMEOUT
		
		while [ "$timeout" -gt "0" ]; do
			echo -n "Check for Space Status == Open: "
			isopen=$(space_is_open)			
			echo "$isopen"			
			
			
			# if closed, decement timeout
			if [ "$isopen" == "true" ]; then
				if [ "$timeout" -lt "$TIMEOUT" ]; then
					# blink off
					i2c_set 0x22 0xa0
				fi

				timeout=$TIMEOUT
				echo "SpaceTime active, timeout reset."
			else
				echo -n "No active SpaceTime detected. "
				echo "$timeout seconds remaining until door is locked."
				let "timeout=$timeout-$DELAY"
				# slow blink and beep
				i2c_set 0x22 0x21
				i2c_set 0x22 0x12
			fi
			
			sleep $DELAY
		done; # while timeout > 0				
		
		# now it is closed -> close the door
		echo "Closing door since SpaceStatus is closed!"
		logger -t lockfailsafe Closing door due to inactive SpaceTime status.
		# with fast blink and beep-beep
		i2c_set 0x22 0x22
		i2c_set 0x22 0x9a
		./door-close.sh
		
		# give the door some time to close
		sleep 5
	
		# blink off
		i2c_set 0x22 0xa0	
	fi # unlocked

	sleep 2
done
