#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <verilator> or <spike>"
    exit 1
fi


file_path1="software/gemmini-rocc-tests/bareMetalC/conv_layer.c"


# For loop to run the script with multiple values of approximate level
for ((i=140; i<=170; i++))
do

    sed -i "s/NO_ACTIVATION, 1.0 \/ [0-9]\+, 0, 0, 0,/NO_ACTIVATION, 1.0 \/ $i, 0, 0, 0,/" "$file_path1"

    # This script can only be ran with verilator. spike simply doesn't work with the appr multiplier.
    ./scripts/run-spike.sh conv_layer > tmp.txt 2>/dev/null

    # Extract output_mat and save it in gemmini.output.txt
    ./clean_output.sh tmp.txt

    # Compile and run the golden model which is convolution.c, output_mat is stored in CPU_output.txt
    mse=$(python evaluate_results.py)

    echo "scale = $i"
    echo "MSE = $mse"
    echo ""

done
#rm output.txt conv


