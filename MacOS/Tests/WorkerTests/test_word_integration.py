"""Opt-in real model smoke test; synthetic speech is not singing-accuracy evidence."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).parents[3]
WORKER = ROOT / "MacOS/Sources/MiniVoice/Resources/align_lyrics.py"


@unittest.skipUnless(os.environ.get("MINIVOICE_TEST_AI_WORD") == "1", "opt-in local model integration")
class WordAlignmentIntegrationTests(unittest.TestCase):
    def test_real_model_on_system_synthesized_speech(self):
        python = Path(os.environ.get("MINIVOICE_AI_PYTHON", str(Path.home() / "Library/Application Support/MiniVoice/LyricsAI/venv/bin/python3")))
        model_directory = Path(os.environ.get("MINIVOICE_AI_MODELS", str(ROOT / "MacOS/Vendor/LyricsAI/arm64")))
        ffprobe, ffmpeg = shutil.which("ffprobe"), shutil.which("ffmpeg")
        self.assertTrue(python.is_file(), "Provide MINIVOICE_AI_PYTHON")
        self.assertTrue((model_directory / "small.pt").is_file(), "Provide local small.pt; no download is performed")
        self.assertTrue(ffprobe and ffmpeg, "Local FFmpeg/FFprobe are required")
        with tempfile.TemporaryDirectory(prefix="minivoice-word-smoke-") as directory:
            work = Path(directory)
            audio, request, output, status = [work / name for name in ("synthetic.aiff", "request.json", "result.json", "status.txt")]
            text = "This is a simple test for the music player."
            subprocess.run(["/usr/bin/say", "-v", "Samantha", "-r", "145", "-o", str(audio), text], check=True, timeout=30)
            duration = float(subprocess.check_output([ffprobe, "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", str(audio)], text=True))
            request.write_text(json.dumps({"audioPath": str(audio), "duration": duration, "lines": [text], "anchors": [0.0], "language": "en", "modelDirectory": str(model_directory), "model": "small", "granularity": "word"}))
            environment = {**os.environ, "MINIVOICE_ALIGNMENT_THREADS": "2", "PYTHONDONTWRITEBYTECODE": "1", "PATH": str(Path(ffmpeg).parent) + os.pathsep + os.environ.get("PATH", "")}
            result = subprocess.run([str(python), str(WORKER), str(request), str(output), str(status)], env=environment, text=True, capture_output=True, timeout=180)
            self.assertEqual(result.returncode, 0, result.stderr[-4000:])
            rows = json.loads(output.read_text())
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]["text"], text)
            self.assertEqual(rows[0]["start"], 0.0)
            self.assertEqual("".join(word["text"] for word in rows[0]["words"]), text)
            self.assertGreater(len(rows[0]["words"]), 1)
            previous = 0
            for word in rows[0]["words"]:
                self.assertGreaterEqual(word["start"], previous)
                self.assertGreater(word["end"], word["start"])
                self.assertLessEqual(word["end"], duration)
                self.assertGreaterEqual(word.get("probability", 1), .35)
                previous = word["end"]


if __name__ == "__main__":
    unittest.main()
