#!/bin/bash

SERVER="transformer-app.py"
NUM_CLIENT=4
DEVICE_LIST=('gpu' 'gpu' 'cpu' 'cpu')
CLIENT="../client_simulator/transformer_client_simulator.py"
CFG_DIR="../Transformer-related/configs/train_queue"
CFG_DIR_AFTER="../Transformer-related/configs/test_queue"
PID_LIST=()

run_client() {
	echo "Starting CLIENT $1..."
	local uuid="$1"
	local logfile="./logs/mobile_client_log_$1.txt"
	python $CLIENT --client_uuid $uuid --device ${DEVICE_LIST[$1]} > $logfile 2>&1 &
	local client_pid=$!
	echo "CLIENT$1_PID = $client_pid"
	PID_LIST+=($client_pid)
}

run_cfg() {
	echo "STARTING TRAINING CONFIG $1"

	echo "Restarting EMQX broker..."
	docker stop emqx && docker start emqx && sleep 5

	echo "Starting SERVER..."
	python $SERVER --num-client $NUM_CLIENT --config $1 > ./logs/server_log.txt 2>&1 &
	export SERVER_PID=$! && echo "SERVER_PID = $SERVER_PID"
	sleep 10

	for client_id in $(seq 0 $(($NUM_CLIENT-1))); do
		run_client $client_id
	done

	while true; do
		ps cax | grep $SERVER_PID > /dev/null
		if [[ $? -ne 0 ]]; then
			echo "FINISHED training config $1"
			for pid in "${PID_LIST[@]}"; do
				kill $pid
			done
			mv -v $1 $CFG_DIR_AFTER
			printf '=%.0s' {1..100}
			break
		fi
		sleep 1
	done
}

for CFG in $CFG_DIR/*.json; do
	run_cfg $CFG
done
