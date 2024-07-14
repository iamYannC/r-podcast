from imports import *
from functions import *

input_file = r"fulll eps\24-w26.mp3"
output_folder = "cut eps"

# Split into 10-minute chunks (600000 milliseconds)
split_mp3(input_file, output_folder)
