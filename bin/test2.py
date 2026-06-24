# Simple script to preprocess the file with the latest function
import re

def preprocess_file_v4(input_file, output_file, known_columns):
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

# List of known column names remains unchanged

# List of known column names
known_columns = [
    "Time", "Users", "Time Remaining", "TPS", "Errors", "CPU User", "CPU Sys", 
    "CPU IOWait", "CPU Idle", "CPU Time", "Memory", "Free", "Tmp Blks Read",
    "Tmp Blks Write", "Blks Read", "Blks Write",  "Scheduler", "User I/O", 
    "System I/O", "Concurrency", "Application", "Commit", "Configuration", 
    "Administrative", "Network", "Queuing", "Other"
]

# File paths
input_filename = '/Users/stefan.oehrli/Development/github/oehrlis/secbench_data/output/db19/soe-regular-10.log'
output_filename = '/Users/stefan.oehrli/Development/github/oehrlis/secbench_data/output/db19/processed_soe-regular-10.csv'

# Run the preprocessing
preprocess_file_v4(input_filename, output_filename, known_columns)

# Path to the processed file for download
processed_file_path = output_filename

processed_file_path

