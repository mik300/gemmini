#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <layer name> (conv_1 layer1_0_conv1 layer1_0_conv2 layer2_0_conv1 layer2_0_conv2 layer3_0_conv1 layer3_0_conv2 linear)"
    exit 1
fi

layers_list=(conv_1 layer1_0_conv1 layer1_0_conv2 layer2_0_conv1 layer2_0_conv2 layer3_0_conv1 layer3_0_conv2 linear)
# Function to find the index of an element
get_index() {
    local element="$1"
    for i in "${!layers_list[@]}"; do
        if [[ "${layers_list[i]}" == "$element" ]]; then
            echo "$i"  # Return the index if found
            return 0   # Exit function
        fi
    done
    echo "-1"  # Return -1 if not found
}

if [ "$1" != "linear" ]; then
    file_path="software/gemmini-rocc-tests/bareMetalC/conv_layer.c"
else
    file_path="software/gemmini-rocc-tests/bareMetalC/linear_layer.c"
fi

sed -i "s/const bool FAST = [0-9]\+/const bool FAST = 0/" "$file_path"

#if it's layer layer2_0_conv1 or layer3_0_conv1 then STRIDE should be set to 2
if [[ "$1" == "layer2_0_conv1" || "$1" == "layer3_0_conv1" ]]; then
    sed -i "s/const int STRIDE = [0-9]\+/const int STRIDE = 2/" "$file_path"
else 
    sed -i "s/const int STRIDE = [0-9]\+/const int STRIDE = 1/" "$file_path"
fi

if [ "$1" != "linear" ]; then
    python change_layer.py software/gemmini-rocc-tests/bareMetalC/conv_layer.c "$1"
fi


# For loop to run the script with multiple values of approximate level
for ((i=150; i<=165; i+=1))
do
    
    sed -i "s/NO_ACTIVATION, 1.0 \/ [0-9]\+,/NO_ACTIVATION, 1.0 \/ $i,/" "$file_path"

    # This script can only be ran with verilator. spike simply doesn't work with the appr multiplier.
    if [ "$1" != "linear" ]; then
       ./scripts/run-spike.sh conv_layer > tmp.txt 2>/dev/null
    else
       ./scripts/run-spike.sh linear_layer > tmp.txt 2>/dev/null
    fi
    

    # Extract output_mat and save it in gemmini.output.txt
    ./clean_output.sh tmp.txt

    index=$(get_index "$1")

    # Compile and run the golden model which is convolution.c, output_mat is stored in CPU_output.txt
    errors=$(python evaluate_results.py --output_mat "$index")

    echo "scale = $i"   
    echo "$errors"
    echo ""

done