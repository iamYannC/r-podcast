from imports import *
from functions import *

input_file = r"fulll eps\24-w26.mp3"
output_file = r"cut eps\conv_cut.mp3"
output_folder = r"cut eps"

start_time = 0  
end_time = to_milliseconds(10)   

# cut_mp3(input_file, output_file, start_time, end_time)



# Example usage

# Split into 10-minute chunks (600000 milliseconds)
split_mp3(input_file, output_folder)