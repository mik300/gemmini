#!/bin/bash




file_path1="software/gemmini-rocc-tests/bareMetalC/conv_layer.c"
file_path2="convolution.c"


#set #define IN_COL_DIM in convolution.c to the proper value depending on $1

sed -i "s/#define IN_COL_DIM [0-9]\+/#define IN_COL_DIM 17/" "$file_path1"



# For loop to run the script with multiple values of approximate level
for ((i=0; i<=8; i++))
do
    # Modify the appr level in both files
    sed -i "s/gemmini_config_multiplier([0-9]\+, [0-9]\+)/gemmini_config_multiplier(255, 16383)/" "$file_path1"

    # This script can only be ran with verilator. spike simply doesn't work with the appr multiplier.
    ./scripts/run-verilator.sh $1 > tmp.txt 2>/dev/null

    # Extract output_mat and save it in gemmini.output.txt
    ./clean_output.sh

    # Compile and run the golden model which is convolution.c, output_mat is stored in CPU_output.txt
    gcc convolution.c -o conv && ./conv > CPU_output.txt

    # Compare the results, if different exit with error message
    if ! diff gemmini_output.txt CPU_output.txt >/dev/null; then
        echo "gemmini_output.txt and CPU_output.txt are different, campaign aborted."
        exit 1
    fi

    # If results are equal proceed with the script 
    echo "Test with approximate = $i passed."
    

done
#rm output.txt conv
echo "Campaign is done. CPU and Gemmini output match."

