#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <verilator> or <spike>"
    exit 1
fi


layers_list=(conv_1 layer1_0_conv1 layer1_0_conv2 layer2_0_conv1 layer2_0_conv2 layer3_0_conv1 layer3_0_conv2 linear)
scale=(157 276 155 221 304 382 452 49)
# For loop to run the script for all layers of resnet8
for ((i=0; i<8; i++))
do

    
    if [ "$i" -eq 7 ]; then
        file_path="software/gemmini-rocc-tests/bareMetalC/linear_layer.c"
    else 
        file_path="software/gemmini-rocc-tests/bareMetalC/conv_layer.c"
        # Modify the layer name in conv_layer.c
        python change_layer.py software/gemmini-rocc-tests/bareMetalC/conv_layer.c "${layers_list[$i]}"
    fi

    sed -i "s/const bool FAST = [0-9]\+/const bool FAST = 0/" "$file_path"
    
    #if it's layer layer2_0_conv1 or layer3_0_conv1 then STRIDE should be set to 2
    if [[ "$i" -eq 3 || "$i" -eq 5 ]]; then
        sed -i "s/const int STRIDE = [0-9]\+/const int STRIDE = 2/" "$file_path"
    else 
        sed -i "s/const int STRIDE = [0-9]\+/const int STRIDE = 1/" "$file_path"
    fi

    # Set scale depending on the layer
    sed -i "s/NO_ACTIVATION, 1.0 \/ [0-9]\+,/NO_ACTIVATION, 1.0 \/ ${scale[$i]},/" "$file_path"

    #if linear layer set BIAS to true
    if [ "$i" -eq 7 ]; then
        sed -i "s/const int NO_BIAS = [0-9]\+/const int NO_BIAS = 0/" "$file_path"
        ./scripts/run-"$1".sh linear_layer > tmp.txt
        if [ $? -ne 0 ]; then
            echo "Error: Predictions don't match, compare gemmini_output.txt and output_mat_8.txt for details."
            echo "Script terminated."
            exit 1  # Terminate the bash script with an error status
        fi
    else 
        sed -i "s/const int NO_BIAS = [0-9]\+/const int NO_BIAS = 1/" "$file_path"
        ./scripts/run-"$1".sh conv_layer > tmp.txt
    fi

    # Extract output_mat and save it in gemmini_output.txt
    ./clean_output.sh tmp.txt
    echo "${layers_list[$i]}:"
    errors=$(python evaluate_results.py --output_mat "$i")    
    echo "$errors"
    echo ""

done
echo "Predictions match"

