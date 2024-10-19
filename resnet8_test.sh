#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <verilator> or <spike>"
    exit 1
fi


file_path1="software/gemmini-rocc-tests/bareMetalC/conv_layer.c"




layers_list=(conv_1 layer1_0_conv1 layer1_0_conv2 layer2_0_conv1 layer2_0_conv2 layer3_0_conv1 layer3_0_conv2)
scale=(157 276 155 221 304 382 452)
# For loop to run the script for all layers of resnet8
for ((i=0; i<7; i++))
do
    # Modify the layer name in conv_layer.c
    echo "${layers_list[$i]}"
    python change_layer.py software/gemmini-rocc-tests/bareMetalC/conv_layer.c "${layers_list[$i]}"

    #if it's layer layer2_0_conv1 or layer3_0_conv1 then STRIDE should be set to 2
    if [[ "$i" -eq 3 || "$i" -eq 5 ]]; then
        sed -i "s/const int STRIDE = [0-9]\+/const int STRIDE = 2/" "$file_path1"
    else 
        sed -i "s/const int STRIDE = [0-9]\+/const int STRIDE = 1/" "$file_path1"
    fi

    # Set scale depending on the layer
    sed -i "s/NO_ACTIVATION, 1.0 \/ [0-9]\+, 0, 0, 0,/NO_ACTIVATION, 1.0 \/ ${scale[$i]}, 0, 0, 0,/" "$file_path1"

    #if linear layer set BIAS to true
    if [ "$i" -eq 7 ]; then
        sed -i "s/const int NO_BIAS = [0-9]\+/const int NO_BIAS = 0/" "$file_path1"
    else 
        sed -i "s/const int NO_BIAS = [0-9]\+/const int NO_BIAS = 1/" "$file_path1"
    fi

    # This script can only be ran with verilator. spike simply doesn't work with the appr multiplier.
    ./scripts/run-spike.sh conv_layer > tmp.txt 2>/dev/null

    # Extract output_mat and save it in gemmini_output.txt
    ./clean_output.sh tmp.txt

    errors=$(python evaluate_results.py --output_mat "$i")    
    echo "$errors"
    echo ""
done
#rm output.txt conv
echo "Campaign is done."

