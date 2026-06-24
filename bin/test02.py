
import re
def parse_filename(file_name):
    # Extract benchmark and number of users from the file name
    match = re.search(r'soe-(.+)-(\d+)\.log', file_name)
    if match:
        benchmark = match.group(1)
        users = match.group(2)
        return benchmark, users
    else:
        return "Unknown", 0

# Test cases
test_filenames = [
    "benchmark-10.log",
    "test-25.csv",
    "singleword.log",
    "complex-benchmark-name-50.txt",
    "invalid-format",
    "",
    "soe-regular-10.log"
]

# # Test cases
# test_filenames = ["soe-regular-10.log"]

# Test the function
for filename in test_filenames:
    benchmark, users = parse_filename(filename)
    print(f"Filename: {filename} -> Benchmark: {benchmark}, Users: {users}")