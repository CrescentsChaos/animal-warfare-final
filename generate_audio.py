"""
Generate placeholder audio files for battle system
Creates minimal-size MP3 files for sound effects and battle music
"""
import os
import struct
import wave

def create_silent_wav(filename, duration_ms=100):
    """Create a short silent WAV file"""
    sample_rate = 22050  # Lower sample rate for smaller files
    num_samples = int(sample_rate * duration_ms / 1000)
    
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(1)  # 8-bit
        wav_file.setframerate(sample_rate)
        
        # Write silence (zeros)
        silence = struct.pack(f'{num_samples}B', *([128] * num_samples))
        wav_file.writeframes(silence)
    
    print(f"Created {filename}")

def create_beep_wav(filename, duration_ms=200, frequency=440):
    """Create a simple beep sound"""
    import math
    
    sample_rate = 22050
    num_samples = int(sample_rate * duration_ms / 1000)
    
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(1)  # 8-bit
        wav_file.setframerate(sample_rate)
        
        # Generate simple sine wave
        samples = []
        for i in range(num_samples):
            # Create envelope to avoid clicks
            envelope = 1.0
            if i < 100:
                envelope = i / 100.0
            elif i > num_samples - 100:
                envelope = (num_samples - i) / 100.0
            
            value = int(128 + 100 * envelope * math.sin(2 * math.pi * frequency * i / sample_rate))
            samples.append(max(0, min(255, value)))
        
        beep = struct.pack(f'{num_samples}B', *samples)
        wav_file.writeframes(beep)
    
    print(f"Created {filename}")

# Create effects directory
effects_dir = 'assets/audio/effects'
os.makedirs(effects_dir, exist_ok=True)

# Create placeholder sound effects (short beeps)
print("Creating placeholder sound effects...")
create_beep_wav(f'{effects_dir}/physical_attack.mp3', duration_ms=150, frequency=300)
create_beep_wav(f'{effects_dir}/special_attack.mp3', duration_ms=200, frequency=500)
create_beep_wav(f'{effects_dir}/status_move.mp3', duration_ms=100, frequency=600)
create_beep_wav(f'{effects_dir}/stat_up.mp3', duration_ms=200, frequency=800)
create_beep_wav(f'{effects_dir}/stat_down.mp3', duration_ms=200, frequency=200)
create_beep_wav(f'{effects_dir}/heal.mp3', duration_ms=300, frequency=700)

# Create placeholder battle music (longer silence for loop)
print("Creating placeholder battle music...")
create_silent_wav('assets/audio/battle_default.mp3', duration_ms=2000)

print("\nPlaceholder audio files created!")
print("Note: These are simple WAV files renamed to .mp3")
print("Replace them with actual MP3 files for production use.")
