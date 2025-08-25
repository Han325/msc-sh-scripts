# MSc SSE Individual Research Project Submission Details

This markdown document contains the details of the code artifiact submissions made for the MSc research project.

## About
This repository contains the various shell scripts that are used to automate the experiments including generating the test suite, code coverage analysis and mutation testing. 

# Test Automation and Mutation Testing Scripts

This collection contains shell scripts for automated testing, code coverage analysis, and mutation testing of web applications (primarily Dimeshift and Retroboard projects).

## Main Categories

**Code Coverage Analysis (`cc_*.sh`)**
- Automated test execution with coverage measurement over multiple runs (15 runs each)
- Calculates Area Under Curve (AUC) for coverage metrics
- Processes fault discovery data and generates reports
- Separate scripts for baseline and enhanced versions

**Mutation Testing (`run_mutation_testing_*.sh`, `apply-mutant*.sh`)**
- Applies code mutations via patch files to test suite effectiveness
- Runs test suites against mutated code to calculate mutation scores
- Supports targeted mutation testing with specific mutant lists
- Includes retry logic for handling unstable test environments

**Experiment Runners (`run_*.sh`)**
- Orchestrates long-running test generation experiments
- Manages multiple sequential runs with automatic cleanup
- Handles file organization and result preservation
- Includes resume functionality for interrupted runs

**Utilities**
- `calculate-auc.sh`: Computes coverage area under curve using trapezoidal rule
- `check-mutation*.sh`: Analyzes and organizes mutation test results
- `setup-vm.sh`: VM environment setup for Docker, Maven, and dependencies

These scripts automate complex testing workflows for research in automated test generation and mutation testing effectiveness.
