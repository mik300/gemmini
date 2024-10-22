import numpy as np
import argparse

def extract_error_lines(file_path):
    try:
        # Open the file in read mode
        with open(file_path, 'r') as file:
            # Iterate over each line in the file
            for line in file:
                # Check if the line starts with one of the specified error strings
                if (line.startswith("Mean Absolute Error") or
                    line.startswith("Mean Squared Error") or
                    line.startswith("Maximum Absolute Error")):
                    # Print the matching line
                    print(line.strip())
    except FileNotFoundError:
        print(f"Error: The file '{file_path}' was not found.")
    except Exception as e:
        print(f"An error occurred: {e}")

def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input_file', default="tmp.txt", type=str)
    return parser.parse_args()

# Main function
def main():
    args = get_args()
    extract_error_lines(args.input_file)

# Run the main function
if __name__ == "__main__":
    main()