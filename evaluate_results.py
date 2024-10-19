import numpy as np
import argparse

def read_matrix_from_file(filename):
    with open(filename, 'r') as f:
        # Skip the first line and read the remaining lines
        matrix = []
        for line in f.readlines()[1:]:  # Skip the first line
            stripped_line = line.strip()
            if stripped_line:  # Check if the line is not empty
                # Convert the line to a list of integers, removing brackets
                row = list(map(int, stripped_line.strip('[]').split(',')))
                matrix.append(row)
    return np.array(matrix)

def evaluate_matrices(A, B):
    """Compute error metrics between two matrices."""
    # Mean Absolute Error
    mae = np.mean(np.abs(A - B))
    
    # Mean Squared Error
    mse = np.mean((A - B) ** 2)
    
    # Root Mean Squared Error
    rmse = np.sqrt(mse)
    
    # Maximum Absolute Error
    max_ae = np.max(np.abs(A - B))
    
    return mae, mse, rmse, max_ae

def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output_mat', default="1", type=str)
    return parser.parse_args()

# Main function
def main():
    args = get_args()
    matrix_number = str(int(args.output_mat) + 1)
    # Read matrices from text files
    A = read_matrix_from_file('gemmini_output.txt')
    B = read_matrix_from_file(f'verified_outputs/output_mat_{matrix_number}.txt')
    
    # Ensure both matrices have the same shape
    if A.shape != B.shape:
        raise ValueError(f"The matrices in gemmini_output.txt {A.shape} and output_mat_{matrix_number}.txt {B.shape} must have the same shape for comparison.")
    
    # Evaluate matrices
    mae, mse, rmse, max_ae = evaluate_matrices(A, B)
    
    # Print results
    print(f"Mean Absolute Error (MAE) = {mae}")
    print(f"Mean Squared Error (MSE) = {mse}")
    print(f"Root Mean Squared Error (RMSE) = {rmse}")
    print(f"Maximum Absolute Error (Max AE) = {max_ae}")

# Run the main function
if __name__ == "__main__":
    main()
