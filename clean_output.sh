#!/bin/bash

#!/bin/bash

# Define the input file and output file
input_file="output.txt"
output_file="gemmini_output.txt"

# Find the line number where "output:" occurs
start_line=$(grep -n "output_mat:" "$input_file" | cut -d ":" -f 1)

# Find the line number where the first empty line occurs after "output:"
end_line=$(awk 'NR > '"$start_line"' && NF == 0 {print NR; exit}' "$input_file")

# If "output:" was found and an empty line after that, copy the lines between them
if [ -n "$start_line" ] && [ -n "$end_line" ]; then
    sed -n "${start_line},${end_line}p" "$input_file" > "$output_file"
else
    echo "Error: Could not find 'output:' or an empty line after it."
fi
