#!/usr/bin/env python3
"""
transcribe.py
Simple transcription wrapper supporting multiple backends.
Usage: transcribe.py <wav_path> <out_path> [--engine google|whisper]

Backends:
- google: SpeechRecognition's recognize_google (free web API)
- whisper: (optional) run local whisper if installed; user must install dependencies
"""
import sys
from pathlib import Path


def transcribe_google(wav_path: str) -> str:
    import speech_recognition as sr
    r = sr.Recognizer()
    with sr.AudioFile(wav_path) as src:
        audio = r.record(src)
    try:
        return r.recognize_google(audio)
    except Exception as e:
        return f"ERROR: {e}"


def transcribe_whisper(wav_path: str) -> str:
    # Lightweight interface to whisper CLI if available in PATH
    import shutil, subprocess
    if shutil.which('whisper'):
        cmd = ['whisper', wav_path, '--model', 'small', '--language', 'en', '--output_format', 'txt', '--no_speech_threshold', '0.1']
        subprocess.check_call(cmd)
        txt_path = Path(wav_path).with_suffix('.txt')
        if txt_path.exists():
            return txt_path.read_text(encoding='utf-8')
        # whisper may output to a new dir; try common locations
        for p in Path('.').glob('**/*.txt'):
            if p.name == txt_path.name:
                return p.read_text(encoding='utf-8')
        return 'ERROR: whisper ran but output not found'
    else:
        return 'ERROR: whisper CLI not installed in PATH'


def main():
    if len(sys.argv) < 3:
        print('Usage: transcribe.py <wav_path> <out_path> [--engine google|whisper]')
        sys.exit(2)
    wav = sys.argv[1]
    out = sys.argv[2]
    engine = 'google'
    if len(sys.argv) > 3 and sys.argv[3].startswith('--engine'):
        engine = sys.argv[3].split('=')[-1] if '=' in sys.argv[3] else sys.argv[4] if len(sys.argv) > 4 else 'google'

    if engine == 'google':
        txt = transcribe_google(wav)
    elif engine == 'whisper':
        txt = transcribe_whisper(wav)
    else:
        txt = f'ERROR: unknown engine {engine}'

    Path(out).write_text(txt, encoding='utf-8')
    print(txt)


if __name__ == '__main__':
    main()
