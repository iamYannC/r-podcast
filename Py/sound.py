#TODO: Automate downloading of episodes
#TODO: Handle memory allocation
#TODO: Something is off in figures `output` > 1. spectrogram disappeared and sound intensity is weird.

from os import chdir
chdir("Py")

from imports import *
from functions import *

input_folder = "cut eps"
output_folder = "figures"

analyze_audio_files(input_folder, output_folder)
