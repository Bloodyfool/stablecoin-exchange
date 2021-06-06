#!/bin/bash

export TRANSACTIONS_TO_DO=1024
# export TRANSACTIONS_TO_DO=10
export PROCESSES=()

# client:gateway:checkpoint_freq
A=(
    4:1:1
    4:1:2
    4:1:4
    4:1:8
)

# simple test
# A=( 2:1:2 )

# echo ${A[@]}
# exit

function run_docker {
    docker system prune -f
    docker volume rm gateway_sync
    docker network prune -y
    rm backend/eval/keys/* || true
    docker-compose -f docker-compose-eval.yml up --scale gateway=$GATEWAYS --scale client=$CLIENTS --build | tee eval_data/$a.log
    rm backend/eval/keys/* || true
}

function clean_up {
    # Perform program exit housekeeping
    echo KILLING
    kill -9 $PROCESSES
    exit
}

trap clean_up SIGHUP SIGINT SIGTERM

function run_local {
    (rm eval/keys/*     || true) > /dev/null 2>&1
    (rm eval/sync/*     || true) > /dev/null 2>&1
    (rm eval/database/* || true) > /dev/null 2>&1

    export PORT=8090
    export BASE_DIR=eval

    export IS_GATEWAY=1
    for i in $(seq 1 $GATEWAYS)
    do
        echo STARTNG GATEWAY $PORT
        pipenv run python stablecoin/run_eval.py &
        PROCESSES+=($!)
        ((PORT=PORT+1))
    done

    IS_GATEWAY=0
    for i in $(seq 1 $CLIENTS)
    do
        echo STARTNG CLIENT $PORT
        pipenv run python stablecoin/run_eval.py &
        PROCESSES+=($!)
        ((PORT=PORT+1))
    done
    wait $PROCESSES
    PROCESSES=()
    sleep 1
	return
}

# cd ./backend

for a in ${A[@]}
do
    export CLIENTS=${a%:*:*}
    tmp=${a#"$CLIENTS"}
    tmp=${tmp#:}
    export GATEWAYS=${tmp%:*}
    tmp=${tmp#"$GATEWAYS"}
    export CHECKPOINT_EVERY=${tmp#:}

    run_docker
    # run_local

done
