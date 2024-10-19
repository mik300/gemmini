import argparse

# Define the layers list
layers_list = [
    "conv_1", 
    "layer1_0_conv1", 
    "layer1_0_conv2", 
    "layer2_0_conv1", 
    "layer2_0_conv2", 
    "layer3_0_conv1", 
    "layer3_0_conv2", 
    "linear"
]

def replace_layers_in_file(input_file, replacement):
    # Read the content of the file
    with open(input_file, 'r') as file:
        content = file.read()

    # Replace each layer in the content
    for layer in layers_list:
        new_content = content.replace(layer, replacement)
        if new_content != content:  # Check if a replacement was made
            break 

    
    # Write the modified content back to the file
    with open(input_file, 'w') as file:
        file.write(new_content)

def main():
    # Set up command line argument parsing
    parser = argparse.ArgumentParser(description="Replace layers in a text file with a specified replacement.")
    parser.add_argument('input_file', type=str, help='The path to the input text file.')
    parser.add_argument('replacement', type=str, help='The string to replace layers with.')

    args = parser.parse_args()
    if args.replacement not in layers_list:
        print(f"Error: '{args.replacement}' is not valid")
        sys.exit(1)
    # Replace layers in the specified file
    replace_layers_in_file(args.input_file, args.replacement)

if __name__ == "__main__":
    main()
