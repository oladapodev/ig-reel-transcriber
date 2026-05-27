#!/usr/bin/env python3
import sys
from pathlib import Path

def transcribe_wav(wav_path: str) -> str:
    import speech_recognition as sr
    r = sr.Recognizer()
    with sr.AudioFile(wav_path) as src:
        audio = r.record(src)
    try:
        text = r.recognize_google(audio)
    except Exception as e:
        text = f"ERROR: {e}"
    return text

if __name__ == '__main__':
    wav = sys.argv[1]
    out = sys.argv[2]
    txt = transcribe_wav(wav)
    Path(out).write_text(txt)
    print(txt)
