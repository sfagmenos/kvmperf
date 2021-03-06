#!/bin/bash

#For such test you need 2 main arguments.
#If it is going to the guest or to the bare metal
#

TEST="all"
GUEST_IP=""
KERNEL="linux-3.17"
KERNEL_TAR="$KERNEL.tar.gz"
KERNEL_XZ="$KERNEL.tar.xz"
KERNEL_BZ="$KERNEL.tar.xz.bz2"
KB="kernbench"
KB_VER="0.50"
KB_TAR="$KB-$KB_VER.tar.gz"
FIO="fio"
FIO_VER="2.1.10"
FIO_DIR="$FIO-$FIO_VER"
FIO_TAR="$FIO-$FIO_VER.tar.gz"
FIO_TEST_DIR="fio_test"

PBZIP_DIR="pbzip_test"


TIMELOG=$(pwd)/time.txt
TIME="/usr/bin/time --format=%e -o $TIMELOG --append"

refresh() {
  sync && echo 3 > /proc/sys/vm/drop_caches
  sleep 15
}

rm -f $TIMELOG
touch $TIMELOG

usage() {
  echo "Usage: $0 [options]\n"
  echo "Options:"
  echo "\t -t | --test <fio|kernbench|pbzip|all>"
  echo "\t -g | --guest <ip>"
}

SUBTEST=""

while :
do
#  if [[ $1 == "" ]]; then
#    break
#  fi
  case "$1" in
    -t | --test )
      TEST="$2"
      shift 2
      ;;
    -g | --guest )
      GUEST_IP="$2"
      shift 2
      ;;
    -- ) # End of all options
      shift
      break
      ;;
    -* ) # Unknown option
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
    * )
      SUBTEST="$1"
      break
      ;;
  esac
done

fio() {

#random=""
#for RAND in 0 1
#do
#if [ $rand -eq 1 ]; then
#    random="rand"
#fi
#for SIZE in 4k 8k 16k 32k 64k 128k 256k 512k 1024k 2048k
#do
  if [[ "$SUBTEST" == "read" ]]; then
    if [[ "$GUEST_IP" == "" ]]; then
      rm -rf $FIO_TEST_DIR
      mkdir $FIO_TEST_DIR
      cp $KERNEL_XZ $FIO_TEST_DIR
      refresh

      echo reset > /sys/kernel/debug/kvm/exit_stats
      ./$FIO_DIR/$FIO random-read-test.fio
      cat /sys/kernel/debug/kvm/exit_stats
      rm -rf $FIO_TEST_DIR
    else
      #ssh -oBatchMode=yes -o "StrictHostKeyChecking no" -l root $GUEST_IP "cd ~/gkvmperf/localtests/; ./run_all.sh 0 0 0 0 $SIZE $RAND"
      echo reset > /sys/kernel/debug/kvm/exit_stats
      ssh -oBatchMode=yes -o "StrictHostKeyChecking no" -l root $GUEST_IP "cd ~/kvmperf/localtests/; rm -rf $FIO_TEST_DIR; mkdir $FIO_TEST_DIR; cp $KERNEL_XZ $FIO_TEST_DIR; ./fio-2.1.10/fio random-read-test.fio"
      cat /sys/kernel/debug/kvm/exit_stats
    fi
  else
#    cp $KERNEL_XZ $FIO_TEST_DIR
#    refresh
#    echo reset > /sys/kernel/debug/kvm/exit_stats
    if [[ "$GUEST_IP" == "" ]]; then
      rm -rf $FIO_TEST_DIR
      mkdir $FIO_TEST_DIR
      cp $KERNEL_XZ $FIO_TEST_DIR
      refresh

      echo reset > /sys/kernel/debug/kvm/exit_stats
      ./$FIO_DIR/$FIO random-write-test.fio
      cat /sys/kernel/debug/kvm/exit_stats
      rm -rf $FIO_TEST_DIR
    else
      #ssh -oBatchMode=yes -o "StrictHostKeyChecking no" -l root $GUEST_IP "cd ~/gkvmperf/localtests/; ./run_all.sh 0 0 0 0 $SIZE $RAND"
      echo reset > /sys/kernel/debug/kvm/exit_stats
      ssh -oBatchMode=yes -o "StrictHostKeyChecking no" -l root $GUEST_IP "cd ~/kvmperf/localtests/; rm -rf $FIO_TEST_DIR; mkdir $FIO_TEST_DIR; cp $KERNEL_XZ $FIO_TEST_DIR; ./fio-2.1.10/fio random-write-test.fio"
      cat /sys/kernel/debug/kvm/exit_stats
    fi
  fi
#done
#done
}

kernbench() {
  if [[ "$GUEST_IP" == "" ]]; then
    pushd $KERNEL
    echo reset > /sys/kernel/debug/kvm/exit_stats
    ./kernbench -M -H -f
    cat /sys/kernel/debug/kvm/exit_stats
    popd
  else
    echo reset > /sys/kernel/debug/kvm/exit_stats
    ssh -oBatchMode=yes -o "StrictHostKeyChecking no" -l root $GUEST_IP "cd ~/kvmperf/localtests/; pushd $KERNEL; ./kernbench -M -H -f; popd;"
    cat /sys/kernel/debug/kvm/exit_stats
  fi
}

pbzip() {

  if [[ "$GUEST_IP" == "" ]]; then
    rm -rf $PBZIP_DIR
    mkdir $PBZIP_DIR
    cp $KERNEL_XZ $PBZIP_DIR
    echo reset > /sys/kernel/debug/kvm/exit_stats
    pbzip2 -p2 -m500 $PBZIP_DIR/$KERNEL_XZ
    cat /sys/kernel/debug/kvm/exit_stats
    rm $PBZIP_DIR/$KERNEL_BZ

    cp $KERNEL_BZ $PBZIP_DIR
    echo reset > /sys/kernel/debug/kvm/exit_stats
    pbzip2 -d -m500 -p2 $PBZIP_DIR/$KERNEL_BZ
    cat /sys/kernel/debug/kvm/exit_stats
    rm $PBZIP_DIR/$KERNEL_XZ
  else
    echo reset > /sys/kernel/debug/kvm/exit_stats
    ssh -oBatchMode=yes -o "StrictHostKeyChecking no" -l root $GUEST_IP "cd ~/kvmperf/localtests/; rm -rf $PBZIP_DIR; mkdir $PBZIP_DIR; cp $KERNEL_XZ $PBZIP_DIR; pbzip2 -p2 -m500 $PBZIP_DIR/$KERNEL_XZ; rm $PBZIP_DIR/$KERNEL_BZ;"
    cat /sys/kernel/debug/kvm/exit_stats
    echo reset > /sys/kernel/debug/kvm/exit_stats
    ssh -oBatchMode=yes -o "StrictHostKeyChecking no" -l root $GUEST_IP "cd ~/kvmperf/localtests/; rm -rf $PBZIP_DIR; mkdir $PBZIP_DIR; cp $KERNEL_BZ $PBZIP_DIR; pbzip2 -d -p2 -m500 $PBZIP_DIR/$KERNEL_BZ; rm $PBZIP_DIR/$KERNEL_XZ;"
    cat /sys/kernel/debug/kvm/exit_stats
  fi

}


case "$TEST" in
  fio )
    fio
    ;;
  all )
    fio
    kernbench
    pbzip
    ;;
  kernbench )
    kernbench
    ;;
  pbzip )
    pbzip
    ;;
esac



