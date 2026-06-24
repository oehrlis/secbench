# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: analyse_secbench.py
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.com
# Editor.....: Stefan Oehrli
# Date.......: 2023.11.19
# Revision...: 
# Purpose....: Script to analyse results from OraDBA SecBench
# Notes......: --
# Reference..: https://github.com/oehrlis/secbench
# License....: Licensed under the Apache License, Version 2.0 (the "License");
#              you may not use this file except in compliance with the License.
#              You may obtain a copy of the License at
#              http://www.apache.org/licenses/LICENSE-2.0
#              Unless required by applicable law or agreed to in writing, software
#              distributed under the License is distributed on an "AS IS" BASIS,
#              WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#              See the License for the specific language governing permissions and
#              limitations under the License.
# ------------------------------------------------------------------------------
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import os
import re
import sys
import glob

# - Default Values -------------------------------------------------------------
# List of known column names
known_columns = [
    "Time", "Users", "Time Remaining", "TPS", "Errors", "CPU User", "CPU Sys", 
    "CPU IOWait", "CPU Idle", "CPU Time", "Memory", "Free", "Tmp Blks Read",
    "Tmp Blks Write", "Blks Read", "Blks Write",  "Scheduler", "User I/O", 
    "System I/O", "Concurrency", "Application", "Commit", "Configuration", 
    "Administrative", "Network", "Queuing", "Other"
]
# - EOF Default Values ---------------------------------------------------------

# - Functions ------------------------------------------------------------------
# ------------------------------------------------------------------------------
# Function...: preprocess_and_get_average
# Purpose....: Preprocess the given file by removing ANSI color codes, headers,
#              and footers, and then calculate the average of the 'TPS' column.
#              This function assumes that the file is formatted as a log file and
#              converts it into a CSV format for analysis.
# Args.......: input_file (str):        Path to the file to be processed.
#              known_columns (list):    List of known column names to correctly 
#                                       handle spaces in the CSV conversion.
# Returns....: float: The average value of the 'TPS' column in the processed file.
# ------------------------------------------------------------------------------

def preprocess_and_get_average(input_file, known_columns):
    # Assuming preprocess_file function is already defined as per previous discussion
    output_file = 'processed_' + os.path.basename(input_file)
    preprocess_file(input_file, output_file, known_columns)

    # Read the processed file and calculate the average TPS
    df = pd.read_csv(output_file)
    average_tps = df['CPU Sys'].mean()
    return average_tps
# ------------------------------------------------------------------------------
# Function...: preprocess_file
# Purpose....: Preprocess the given file and calculate the average of a specific
#              column.
# Args.......: input_file (str):        Path to the file to be processed.
#              known_columns (list):    List of known column names to correctly 
#                                       handle spaces in the CSV conversion.
# Returns....: float:               The average value of the specified column.
# ------------------------------------------------------------------------------
import re
def preprocess_file(input_file, output_file, known_columns):
    """
    Preprocess the input file: replace ANSI color codes with commas, remove headers and footers, 
    and convert data to CSV format. This version also restores spaces in column names for better readability.

    Args:
    input_file (str): Path to the input file.
    output_file (str): Path to the output file for the processed data.
    known_columns (list): List of known column names to correctly handle spaces.
    """
    with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
        start_processing = False
        for line in infile:
            # Replace ANSI color codes with commas
            line = re.sub(r'\x1b\[[0-9;]*m', ',', line)

            # Check if the line contains any known column names
            if any(col in line for col in known_columns):
                start_processing = True
                # Temporarily replace spaces with underscores in known column names
                for col in known_columns:
                    line = line.replace(col, col.replace(' ', '_'))
                # Replace spaces (and any ANSI codes) with a single comma
                line = re.sub(r'\s+', ',', line)
                line = re.sub(r',+', ',', line)
                # Restore spaces in column names for readability
                for col in known_columns:
                    line = line.replace(col.replace(' ', '_'), col)
                # Clean up leading and trailing commas
                line = line.strip(',')
                outfile.write(line + '\n')
                continue

            # Write the line to output if processing has started
            if start_processing:
                if "Saved results" in line:  # Stop processing at footer
                    break
                # Replace spaces (and any ANSI codes) with a single comma
                line = re.sub(r'\s+', ',', line)
                line = re.sub(r',+', ',', line)
                # Clean up leading and trailing commas
                line = line.strip(',')
                outfile.write(line + '\n')

# ------------------------------------------------------------------------------
# Function...: parse_filename
# Purpose....: Parse the file name to extract benchmark name and the number of users.
# Args.......: file_name (str):     The name of the file to parse.
# Returns....: str:                 A formatted string with extracted information.
# ------------------------------------------------------------------------------
def parse_filename(file_name):
    # Extract benchmark and number of users from the file name
    match = re.search(r'soe-(.+)-(\d+)\.log', file_name)
    if match:
        benchmark = match.group(1)
        users = match.group(2)
        return benchmark, users
    else:
        return "Unknown", 0

# ------------------------------------------------------------------------------
# Function...: list_files
# Purpose....: List all files in the specified directory that match the given pattern.
# Args.......: directory (str):     The directory to search in.
#              pattern (str):       The pattern to match files against.
# Returns....: list:                A list of file paths matching the pattern.
# ------------------------------------------------------------------------------
def list_files(directory, pattern):
    """List files in the given directory that match the pattern."""
    path_pattern = os.path.join(directory, pattern)
    return glob.glob(path_pattern)

# ------------------------------------------------------------------------------
# Function...: main
# Purpose....: Main function to process files in a directory and plot average TPS.
# Args.......: directory (str):     The directory containing files to process.
# ------------------------------------------------------------------------------
def main(directory):
    averages = {}
    users_group = {}
    file_pattern = 'soe-*.log'  # Pattern to match the files

    # List and process files
    file_list = list_files(directory, file_pattern)
    for file in file_list:
        benchmark, users = parse_filename(os.path.basename(file))
        average_tps = preprocess_and_get_average(file, known_columns)
        label = f"{benchmark} ({users} users)"
        avg_tps = preprocess_and_get_average(file, known_columns)
        averages[label] = avg_tps
        if users not in users_group:
            users_group[users] = []
        users_group[users].append((label, avg_tps))

    # Sorting the groups by number of users
    sorted_users_group = sorted(users_group.items(), key=lambda x: int(x[0]))

    # Create a DataFrame from the averages dictionary
    average_df = pd.DataFrame(list(averages.items()), columns=['Label', 'Average TPS'])

    #colors = plt.cm.viridis(np.linspace(0, 1, len(averages)))
    colors = plt.cm.tab20c(np.linspace(0, 1, len(averages)))

    plt.figure(figsize=(12, 6))

    for i, (users, benchmarks) in enumerate(sorted_users_group):
        for j, (label, avg_tps) in enumerate(benchmarks):
            bar = plt.bar(i + j*0.1, avg_tps, color=colors[j], label=label if i==0 else "", width=0.1)
            # Annotate each bar with the value
            plt.text(bar[0].get_x() + bar[0].get_width() / 2, bar[0].get_height(), f'{avg_tps:.2f}', 
                    ha='center', va='top', rotation='vertical')

    plt.xlabel('Number of Users')
    plt.ylabel('Average TPS')
    plt.title('Average TPS by Number of Users')
    plt.xticks([i for i in range(len(sorted_users_group))], [str(users) for users, _ in sorted_users_group])
    plt.legend()
    plt.grid(True)
    plt.show()
# - EOF Functions --------------------------------------------------------------


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <directory>")
        sys.exit(1)

    main(sys.argv[1])

# --- EOF ----------------------------------------------------------------------