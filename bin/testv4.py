# Adjusting the preprocess_file function to correctly handle spaces within the data rows
def preprocess_file_v4(input_file, output_file, known_columns):
    """
    Preprocess the input file: remove ANSI color codes, headers, footers, and convert data to CSV format.
    This version handles columns with spaces in both headers and data rows.

    Args:
    input_file (str): Path to the input file.
    output_file (str): Path to the output file for the processed data.
    known_columns (list): List of known column names to correctly handle spaces.
    """
    with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
        start_processing = False
        for line in infile:
            # Remove ANSI color codes
            line = re.sub(r'\x1b\[[0-9;]*m', '', line)

            # Check if the line contains any known column names
            if any(col in line for col in known_columns):
                start_processing = True
                # Replace spaces with commas except in known column names
                for col in known_columns:
                    line = line.replace(col, col.replace(' ', '_'))
                line = re.sub(r'\s+', ',', line)
                outfile.write(line + '\n')
                continue

            # Write the line to output if processing has started
            if start_processing:
                if "Saved_results" in line:  # Stop processing at footer
                    break
                # Replace multiple spaces with a single comma, except where there is a single space between words
                line = re.sub(r'([^\s])\s\s+([^\s])', r'\1,\2', line)
                line = re.sub(r',\s', ',', line)
                outfile.write(line)

# Re-run the preprocessing with the updated function
preprocess_file_v4(input_filename, output_filename, known_columns)
