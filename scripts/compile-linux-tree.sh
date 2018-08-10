#!/bin/bash
#
# This script tries to compile the sysdig probes against all the stable kernel
# releases that match a specific pattern.
#
# Usage:
#
# compile-linux-tree.sh SYSDIG_SOURCE_DIRECTORY LINUX_TREE PATTERN1 PATTERN2 ...
#
# Example:
#
# compile-linux-tree.sh ~/sysdig_src ~/linux_tree 'v4.1[4-9]*'
#
set -euo pipefail

SYSDIG_SRC_DIR=$1
LINUX_TREE=$2
shift 2
PATTERNS=$@

export KERNELDIR=$LINUX_TREE

cd "$LINUX_TREE"

TAGS=$(git tag -l $PATTERNS | sort -V)

echo "Processing the following versions: $TAGS"

for tag in $TAGS
do
        cd "$LINUX_TREE"
        git checkout "$tag" &> /dev/null

        make distclean &> /dev/null
        make defconfig &> /dev/null
        make modules_prepare &> /dev/null

        cd "$SYSDIG_SRC_DIR"

        make -C driver/bpf clean &> /dev/null
        rm -rf build || true

        set +e

        mkdir build
        cd build
        cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_BPF=ON .. > /dev/null
        make driver VERBOSE=1 > /dev/null
        if [ $? -ne 0 ]; then
                echo "$tag -> ************ failure ************"
                continue
        fi

        make bpf VERBOSE=1 > /dev/null
        if [ $? -ne 0 ]; then
                echo "$tag -> ************ failure ************"
                continue
        fi

        set -e

        echo "$tag -> success"
done

echo "All done"
