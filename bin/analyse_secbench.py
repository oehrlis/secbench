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
# todo:
# - error handling
# - customisation
# - clean up old files / temp file
# - location of temp files
# - directly create a png file

import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import numpy as np
import os
import re
import sys
import glob
import argparse

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
#              column_name (str):       Name of the column to calculate the average of.
#              known_columns (list):    List of known column names to correctly
#                                       handle spaces during preprocessing.
# Returns....: float:                   The average value of the specified column in the processed file.
# ------------------------------------------------------------------------------
def preprocess_and_get_average(input_file, column_name, known_columns):
    # Generate the path for the processed output file in the same directory as the input file
    output_file = output_file = os.path.splitext(input_file)[0] + '.csv'
    preprocess_file(input_file, output_file, known_columns)

    # Read the processed file and calculate the average of the specified column
    df = pd.read_csv(output_file)
    average_value = df[column_name].mean()
    return average_value

# ------------------------------------------------------------------------------
# Function...: usage
# Purpose....: Display the usage information for the script.
# ------------------------------------------------------------------------------
def usage():

    usage_text = """
    Usage: analyse_secbench.py [options]

    Options:
      -h, --help          Show this help message and exit.
      -f FILE, --file FILE
                          Specify a single benchmark log file.
      -d DIRECTORY, --directory DIRECTORY
                          Specify a directory of benchmark log files.
      -s, --single        Create a graphic for a single benchmark file.
                          Requires -f.
      -m, --multiple      Create a grouped bar chart for a list of benchmark files.
                          Requires -d.
      -r ROW, --row ROW   Specify the row used to create a graphic or a grouped bar chart.
                          Default is TPS.
      -b BENCHMARK, --benchmark BENCHMARK
                          Limit the benchmarks to a list provided by a comma-separated string.
                          Example: regular,audit_full,tde_256
      -c, --csv           Convert log files to CSV format. Works with -f or -d.
      -i, --image         Save the graphic as a PNG file instead of displaying on screen.
                          Works with -s or -m.

    Examples:
      python analyse_secbench.py -f benchmark.log -s
      python analyse_secbench.py -d /path/to/logs/ -m -r Errors
      python analyse_secbench.py -d /path/to/logs/ -m -i
    """
    print(usage_text)

# ------------------------------------------------------------------------------
# Function...: preprocess_file
# Purpose....: Preprocess the input file: replace ANSI color codes with commas,
#              remove headers and footers, and convert data to CSV format. This
#              version also restores spaces in column names for better readability.

# Args.......: input_file (str):        input_file (str): Path to the input file.
#              output_file (str):       Path to the output file for the processed data.
#              known_columns (list):    List of known column names to correctly 
#                                       handle spaces in the CSV conversion.
# Returns....: float:               The average value of the specified column.
# ------------------------------------------------------------------------------
def preprocess_file(input_file, output_file, known_columns):
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
# Function...: process_single_file
# Purpose....: Process a single benchmark file and generate a bar chart for the specified row.
# Args.......: input_file (str):        Path to the benchmark file to be processed.
#              known_columns (list):    List of known column names to correctly handle spaces.
#              row (str):               The name of the row (column) in the file to
#                                       be used for analysis. Default is 'TPS'.
# Returns....: list:                    The function generates and displays a time series plot.
# ------------------------------------------------------------------------------
def process_single_file(input_file, known_columns, row='TPS', save_image=False):    
    # Generate the path for the processed output file in the same directory as the input file
    output_file = output_file = os.path.splitext(input_file)[0] + '.csv'
    preprocess_file(input_file, output_file, known_columns)

    # Read the processed file
    df = pd.read_csv(output_file)

    # Convert 'Time Remaining' to timedelta
    df['Time Remaining'] = pd.to_timedelta(df['Time Remaining'])

    # Formatter for the x-axis
    def time_formatter(x, pos):
        td = pd.to_timedelta(x, unit='s')
        return str(td).split()[2] if len(str(td).split()) > 2 else str(td)

    # Plotting
    plt.figure(figsize=(10, 6))
    plt.plot(df['Time Remaining'].dt.total_seconds(), df[row], label=row)
    plt.gca().xaxis.set_major_formatter(ticker.FuncFormatter(time_formatter))

    # Invert x-axis
    plt.gca().invert_xaxis()

    # Add grid lines
    plt.grid(True)

    # Calculate and plot the average line for the specified row
    average_value = df[row].mean()
    plt.axhline(y=average_value, color='r', linestyle='-', label=f'Average {row}: {average_value:.2f}')

    # Customizing the plot
    plt.title(f'{row} Performance Over Time')
    plt.xlabel('Time Remaining (HH:MM:SS)')
    plt.ylabel(row)

    # Show legend
    plt.legend()

    if save_image:
        image_file = os.path.splitext(input_file)[0] + '.png'
        plt.savefig(image_file)
        print(f"Plot saved as {image_file}")
    else:
        plt.show()

    plt.close()  # Close the plot

# ------------------------------------------------------------------------------
# Function...: process_multiple_files
# Purpose....: Process multiple benchmark files from a specified directory and
#              generate a grouped bar chart. This function calculates the average
#              value of a specified row (column) for each benchmark file, groups
#              the data by the number of users, and plots the results.
# Args.......: directory (str):         Path to the directory containing the
#                                       benchmark log files.
#              row (str):               The name of the row (column) in the file
#                                       to be used for analysis. Default is 'TPS'.
#              benchmarks (list, optional): A list of specific benchmarks to include in
#                                          the analysis. If None, all benchmarks in the
#                                          directory are processed. Default is None.
# Returns....: None. The function generates and displays a grouped bar chart.
# ------------------------------------------------------------------------------
def process_multiple_files(directory, row='TPS', benchmarks=None, save_image=False):

    averages = {}
    users_group = {}
    file_pattern = 'soe-*.log'  # Pattern to match the files

    # List and process files
    file_list = list_files(directory, file_pattern)
    for file in file_list:
        benchmark, users = parse_filename(os.path.basename(file))
        # Filter benchmarks if specified
        if benchmarks and benchmark not in benchmarks:
            continue

        # Process the file
        avg_value = preprocess_and_get_average(file, row, known_columns)
        label = f"{benchmark} ({users} users)"
        averages[label] = avg_value
        if users not in users_group:
            users_group[users] = []
        users_group[users].append((label, avg_value))

    # Sorting the groups by number of users
    sorted_users_group = sorted(users_group.items(), key=lambda x: int(x[0]))

    # Plotting logic...
    colors = plt.cm.tab20c(np.linspace(0, 1, len(averages)))
    plt.figure(figsize=(12, 6))
    for i, (users, benchmarks) in enumerate(sorted_users_group):
        for j, (label, avg_value) in enumerate(benchmarks):
            bar = plt.bar(i + j*0.1, avg_value, color=colors[j], label=label if i==0 else "", width=0.1)
            plt.text(bar[0].get_x() + bar[0].get_width() / 2, bar[0].get_height(), f'{avg_value:.2f}', 
                     ha='center', va='top', rotation='vertical')

    plt.xlabel('Number of Users')
    plt.ylabel(f'Average {row}')
    plt.title(f'Average {row} by Number of Users')
    plt.xticks([i for i in range(len(sorted_users_group))], [str(users) for users, _ in sorted_users_group])
    plt.legend()
    plt.grid(True)

    if save_image:
        row_name_for_file = row.replace(" ", "-")
        image_file = os.path.join(directory, f'multiple_benchmarks_{row_name_for_file}.png')
        plt.savefig(image_file)
        print(f"Plot saved as {image_file}")
    else:
        plt.show()

    plt.close()  # Close the plot

def convert_to_csv(input_file, output_file):
    # Generate the path for the processed output file in the same directory as the input file
    output_file = output_file = os.path.splitext(input_file)[0] + '.csv'
    # Function to convert a log file to CSV
    preprocess_file(input_file, output_file, known_columns)

def list_benchmarks_and_rows(file_path):
    """ List benchmarks and rows from a single file """
    preprocess_file(file_path, 'temp.csv', known_columns)  # Assuming known_columns is defined globally
    df = pd.read_csv('temp.csv')
    print(f"Benchmarks in {file_path}:")
    #print(df['Benchmark'].unique())  # Replace 'Benchmark' with the appropriate column name
    print("Available Rows:")
    print(df.columns)

def list_benchmarks_and_rows_directory(directory):
    """ List benchmarks and rows from all files in a directory """
    for file in os.listdir(directory):
        if file.endswith(".log"):
            file_path = os.path.join(directory, file)
            list_benchmarks_and_rows(file_path)

def cleanup_temp_files(pattern='temp_*.csv'):
    """
    Remove temporary files created during script execution.

    Args:
    pattern (str): The pattern to match temporary files. Default is 'temp_*.csv'.
    """
    for temp_file in glob.glob(pattern):
        try:
            os.remove(temp_file)
            print(f"Removed temporary file: {temp_file}")
        except OSError as e:
            print(f"Error: {e.strerror} - {temp_file}")

# ------------------------------------------------------------------------------
# Function...: main
# Purpose....: Main function to process files in a directory and plot average TPS.
# Args.......: directory (str):     The directory containing files to process.
# ------------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description='Benchmark Analysis Tool')
    parser.add_argument('-f', '--file', help='Specify a single benchmark log file')
    parser.add_argument('-d', '--directory', help='Specify a directory of benchmark log files')
    parser.add_argument('-s', '--single', action='store_true', help='Create graphic for a single benchmark file')
    parser.add_argument('-m', '--multiple', action='store_true', help='Create grouped bar chart for a list of benchmark files')
    parser.add_argument('-r', '--row', default='TPS', help='Specify the row for data analysis')
    parser.add_argument('-b', '--benchmark', help='Limit to specific benchmarks (comma-separated)')
    parser.add_argument('-c', '--csv', action='store_true', help='Convert log files to CSV format')
    parser.add_argument('-l', '--list', action='store_true', help='List available benchmarks and rows')
    parser.add_argument('-i', '--image', action='store_true', help='Save the graphic as a PNG file')
    args = parser.parse_args()

    # CSV conversion logic
    if args.csv or args.single or args.multiple:
        if args.csv and not (args.file or args.directory):
            parser.error("The -c option requires either -f or -d.")
        elif args.list and not (args.file or args.directory):
            parser.error("The -l option requires either -f or -d.")
        elif args.single and not args.file:
            parser.error("The -s option requires -f.")
        elif args.multiple and not args.directory:
            parser.error("The -m option requires -d.")

    if args.csv:
        if args.file:
            # Convert a single file to CSV
            output_file = os.path.splitext(args.file)[0] + '.csv'
            convert_to_csv(args.file, output_file)
        elif args.directory:
            # Convert all files in a directory to CSV
            for file in os.listdir(args.directory):
                if file.endswith(".log"):
                    input_path = os.path.join(args.directory, file)
                    output_file = os.path.splitext(input_path)[0] + '.csv'
                    convert_to_csv(input_path, output_file)
    elif args.single and args.file:
        process_single_file(args.file, known_columns, row=args.row, save_image=args.image)
    elif args.multiple and args.directory:
        benchmarks = args.benchmark.split(',') if args.benchmark else None
        process_multiple_files(args.directory, row=args.row, benchmarks=benchmarks, save_image=args.image)
    elif args.list and args.file:
        list_benchmarks_and_rows(args.file)
    elif args.list and args.directory:
        list_benchmarks_and_rows_directory(args.directory)
    else:
        parser.print_help()
    
# - EOF Functions --------------------------------------------------------------

if __name__ == "__main__":
    main()
# --- EOF ----------------------------------------------------------------------