#!/bin/bash

if [ $# -ne 3 ]; then
    echo "Usage: $0 <conv> or <conv_rect> <verilator> or <spike> <approximation level>"
    exit 1
fi

if [ "$1" != "conv" ] && [ "$1" != "conv_rect" ]; then
    echo "The only 2 convolution available are conv or conv_rect (called rect)."
    exit 1
fi

if [ "$2" != "verilator" ] && [ "$2" != "spike" ]; then
    echo "The only 2 simulators available are verilator or spike."
    exit 1
fi

if [ $3 -gt 255 ] || [ $3 -lt 0 ]; then
    echo "Error: approximation level should be between 0 and 255 (both included)."
    exit 1
fi

simulator=$2

file_path1="software/gemmini-rocc-tests/bareMetalC/$1.c"
file_path2="convolution.c"

#set #define IN_COL_DIM in convolution.c to the proper value depending on $1
if [ "$1" == "conv" ]; then
    sed -i "s/#define IN_COL_DIM [0-9]\+/#define IN_COL_DIM 17/" "$file_path2"
else 
    sed -i "s/#define IN_COL_DIM [0-9]\+/#define IN_COL_DIM 28/" "$file_path2"
fi

# Initialize approximate to 255 (100% accuracy) in both files
sed -i "s/gemmini_config_multiplier([0-9]\+, [0-9]\+)/gemmini_config_multiplier($3, 16383)/" "$file_path1"
sed -i "s/#include \"axx_mults_9x9\/bw_mult_9_9_[0-9]\+.h\"/#include \"axx_mults_9x9\/bw_mult_9_9_$((255 - $3)).h\"/" "$file_path2"

# For loop to run the script with multiple values of seed 
for ((i=6; i<=10; i++))
do
    # Modify the seed in both files to the next value and loop again
    sed -i "s/mysrand([0-9]\+)/mysrand($i)/" "$file_path1"
    sed -i "s/mysrand([0-9]\+)/mysrand($i)/" "$file_path2"

    # Choose simulator based on input parameter
    if [ "$simulator" == "verilator" ]; then
        ./scripts/run-verilator.sh $1 > output.txt 2>/dev/null
    else 
        ./scripts/run-spike.sh $1 > output.txt 2>/dev/null
    fi

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
    echo "Test with seed = $i passed."
    

done
#rm output.txt conv
echo "Campaign is done. CPU and Gemmini output match (with appr = $3)."

