# MNIST Hardware Accelerator on Kria KV260 Vision AI 
![](https://github.com/TopGun2001/MNIST-Hardware-Accelerator/blob/main/Images/KriaKV260.jpg)
![](https://github.com/TopGun2001/MNIST-Hardware-Accelerator/blob/main/Images/MNIST.png)

## Getting Started
1. Clone this repository onto a PYNQ-supported Kria KV260 board.
2. Navigate to the Demo/ folder.
3. Launch the Jupyter notebook provided.
4. Ensure the .bit, .hwh, and CSV files are in the correct paths.
5. Run the notebook cells to test the hardware accelerator with MNIST data.

## Requirements
1. AMD Kria KV260 Vision AI Starter Kit
2. PYNQ Framework installed on SD card with Ubuntu OS
3. Vitis HLS for generating HLS IP
4. Xilinx Vivado for RTL synthesis and implementation
5. AMD Brevitas Framework for training quantized models

## Introduction
This project demonstrates a __quantized MNIST hardware accelerator__ implemented on the __AMD Kria KV260 Vision AI Starter Kit__, showcasing both performance and efficiency in digit classification using deep learning techniques on FPGAs. 

## Hardware Architecture
The model architecture is a 784-512-256-10 MLP, trained with the __AMD Brevitas framework__ for quantization-aware training. This is crucial for FPGA implementation because FPGAs are significantly more efficient at handling __fixed-point integer arithmetic__ compared to __floating-point operations__. Integer math not only reduces resource utilization (e.g., LUTs, DSPs, and BRAM) but also enables faster inference and lower power consumption, making it ideal for deploying deep learning models on hardware accelerators.

## Hardware Implementation Types
Two hardware implementations of the model were developed:
- __High-Level Synthesis (HLS)__ design using Vitis C++ HLS
- __Register Transfer Level (RTL)__ design using Verilog/SystemVerilog

## Execution Results
| Type  | Number of Inferences | Execution Time | Time per Inference |
| :---: | :---: | :---: | :---: |
| PyTorch (software) | 10000 | 36.70 seconds | 0.003670 seconds |
| HLS | 10000 | __*4.14 seconds*__ | __*0.000414 seconds*__ |
| RTL | 10000 | 35.20 seconds | 0.003520 seconds |

## Conclusion
Both the software and hardware implementations achieved a high classification accuracy of 96.85% over 10,000 MNIST inferences, validating the correctness of the model across all platforms.

The HLS-based design delivered excellent performance, achieving an almost 10× speedup over the baseline PyTorch software implementation. This performance gain is attributed to effective pipelining and parallelism enabled by the Vitis HLS toolchain, which efficiently mapped the quantized integer operations onto the FPGA fabric.

However, the RTL-based design did not yield a significant speedup. Despite being functionally correct, the RTL implementation encountered resource bottlenecks, particularly with LUTs and BRAMs, which reached near 100% utilization. These constraints prevented effective pipelining and limited parallel execution, ultimately restricting performance gains.

## Repository Structure
1. __Demo__: Contains Jupyter Notebook program to run. Bitstreams and Hardware Handoff files. Input, weights and biases csv files.
   - Place all the files in the same folder as the notebook.
   - .bit and .hwh must have same names else there wil be an error.
   - Run each cell in the notebook for inferencing.

2. __HLS__: Contains Vitis files for the HLS IP.
   - Open Vitis HLS IDE, both old and new versions should work.
   - Add the source, header and test files to project.
   - Select correct part number `xck26-sfvc784-2LV-c` corresponding to Kria KV260 Vision AI starter kit.
   - Now you can run simulation, synthesis, C/RTL co-simulation etc.
     
3. __RTL__: Contains Verilog/SystemVerilog files used for the RTL IP. Also includes the relevant testbench for the module in each of the folders.
   - Open Vivado IDE and add all the design and testbench files.
   - Select the same part number corresponding to the board.
   - You can perform the whole design flow upto bitstream generation

## Contributors
We are Computer Engineering students (Class of 2025) from the National University of Singapore.

1. __Suresh Abijith Ram__
2. __Pang Yan Ming__
3. __Nicholas H Goh Maowen__


