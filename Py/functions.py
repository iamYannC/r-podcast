from imports import *

# make sure ffmpeg is installed and set the path to the executable
AudioSegment.ffmpeg =  r"C:\Users\97253\Documents\Software\Others\ffmpeg-7.0.1-essentials_build\ffmpeg-7.0.1-essentials_build\bin\ffmpeg.exe"
AudioSegment.converter = r"C:\Users\97253\Documents\Software\Others\ffmpeg-7.0.1-essentials_build\ffmpeg-7.0.1-essentials_build\bin\ffmpeg.exe"

# Split mp3 to shorter chuncks
def split_mp3(input_file, output_folder, chunk_length_ms=600000):
    """
    Split an MP3 file into chunks of specified length.
    
    :param input_file: Path to the input MP3 file
    :param output_folder: Folder to save the output chunks
    :param chunk_length_ms: Length of each chunk in milliseconds (default: 10 minutes)
    """
   
    # Load the MP3 file
    audio = AudioSegment.from_mp3(input_file)
    
    # Get the total length of the audio
    total_length_ms = len(audio)
    
    # Split the audio into chunks (default: 600000 = 60 * 10 * 1000 ms)
    for i, start in enumerate(range(0, total_length_ms, chunk_length_ms)):
        # Calculate end time for the chunk
        end = start + chunk_length_ms
        
        # Extract the chunk
        chunk = audio[start:end]
        
        # Generate output filename
        base_name = os.path.splitext(os.path.basename(input_file))[0]
        output_file = os.path.join(output_folder, f"{base_name} - chunk_{i+1}.mp3")
        
        # Export the chunk
        chunk.export(output_file, format="mp3")
        
        print(f"Saved chunk {i+1}: {output_file}")

# Main function - iterate over all MP3 files in the folder and analyze each
def analyze_audio_files(folder_path, output_folder):
    """
    Analyze all MP3 files in the specified folder and create plots for each,
    adjusting the x-axis based on the chunk number.
    
    :param folder_path: Path to the folder containing MP3 files
    :param output_folder: Path to save the output plots
    """
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)
    
    mp3_files = [f for f in os.listdir(folder_path) if f.endswith('.mp3')]
    
    for file in mp3_files:
        file_path = os.path.join(folder_path, file)
        
        # Extract chunk number from filename
        chunk_match = re.search(r'chunk_(\d+)', file)
        if chunk_match:
            chunk_num = int(chunk_match.group(1))
            time_offset = (chunk_num - 1) * 10 * 60  # offset in seconds
        else:
            time_offset = 0
        
        y, sr = librosa.load(file_path)
        
        fig, (ax1, ax2, ax3) = plt.subplots(3, 1, figsize=(12, 15))
        
        # 1. Waveform
        times = np.linspace(time_offset, time_offset + len(y)/sr, num=len(y))
        ax1.plot(times, y)
        ax1.set_title('Waveform')
        ax1.set_xlabel('')
        
        # 2. Spectrogram
        D = librosa.stft(y)
        S_db = librosa.amplitude_to_db(np.abs(D), ref=np.max)
        img = librosa.display.specshow(S_db, sr=sr, x_axis='time', y_axis='hz', ax=ax2)
        fig.colorbar(img, ax=ax2, format='%+2.0f dB')
        ax2.set_title('Spectrogram')
        ax2.set_xlabel('')
        
        # Adjust spectrogram x-axis
        ax2.set_xlim(time_offset, time_offset + len(y)/sr)
        ax2.set_xticks(np.linspace(time_offset, time_offset + len(y)/sr, 5))
        
        # 3. Sound Intensity (RMS Energy)
        S, phase = librosa.magphase(D)
        rms = librosa.feature.rms(S=S)[0]
        rms_times = librosa.times_like(rms, sr=sr) + time_offset
        ax3.semilogy(rms_times, rms, label='RMS Energy')
        ax3.set_ylabel('RMS Energy')
        ax3.set_xlabel('Time (seconds)')
        ax3.set_title('Sound Intensity')
        ax3.legend()
        
        # Adjust x-axis for all subplots
        for ax in (ax1, ax2, ax3):
            ax.set_xlim(time_offset, time_offset + len(y)/sr)
            ax.set_xticks(np.linspace(time_offset, time_offset + len(y)/sr, 5))
            ax.set_xticklabels([f'{int(t/60)}:{int(t%60):02d}' for t in ax.get_xticks()])
        
        plt.tight_layout()
        output_file = os.path.join(output_folder, f"{os.path.splitext(file)[0]}_analysis.png")
        plt.savefig(output_file, dpi=300)
        plt.close(fig)
        
        print(f"Saved analysis for {file} to {output_file}")

if __name__ == "__main__":
    print("wrong script buddy, go to sound.py")