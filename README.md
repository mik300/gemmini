# Overview

This project is a fork of [Gemmini](https://github.com/ucb-bar/gemmini), modified to integrate a custom multiplier developed in [MARLIN](https://github.com/vlsi-lab/MARLIN) for approximate computation. The primary objective was to enhance the Gemmini core by enabling support for configurable approximation levels and precision in arithmetic operations.

## Key Modifications

The original regular multiplier in Gemmini was replaced with the MARLIN approximate multiplier, which introduces two control signals that allow runtime selection of:
- **Approximation Level:** Controls the degree of computational approximation.
- **Precision:** Determines the level of arithmetic accuracy.

To accommodate these features, a custom instruction was added to the Gemmini instruction set, enabling dynamic configuration of the multiplier's behavior.

## Additional Resources

- For details about the original Gemmini framework, refer to the [Gemmini README](https://github.com/ucb-bar/gemmini).
- For specifics about the modifications and implementation in this project, consult the project report included in this repository.

