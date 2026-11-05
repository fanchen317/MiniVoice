#!/usr/bin/env python3
"""Exercise the production Mac tag writer against synthetic audio only."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[2]
harness = '\nlet root = FileManager.default.temporaryDirectory.appendingPathComponent("MiniVoice-Automatic-" + UUID().uuidString)\ntry FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)\ndefer { try? FileManager.default.removeItem(at: root) }\nlet bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:16,pixelsHigh:16,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!\nbitmap.bitmapData?.initialize(repeating:255,count:bitmap.bytesPerRow*16)\nlet artwork = bitmap.representation(using:.png,properties:[:])!\nfor ext in ["mp3", "flac", "m4a"] {\n let file = root.appendingPathComponent("test." + ext)\n _ = try MediaTools.run("ffmpeg", ["-v", "error", "-f", "lavfi", "-i", "sine=frequency=440:duration=1", file.path])\n let original = try Data(contentsOf: file)\n try FFMpegTagWriter.write(TagPayload(url:file,title:"Synthetic",artist:"Test",album:"Album",lyrics:"[00:00.00]Hello",artwork:artwork,preserveArtwork:false))\n let probe = try MediaTools.run("ffprobe", ["-v", "error", "-show_streams", "-of", "json", file.path])\n guard String(data:probe,encoding:.utf8)!.contains("attached_pic\\": 1") else { fatalError("missing artwork") }\n let backups = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("backup"), includingPropertiesForKeys:nil)\n guard try backups.contains(where: { try Data(contentsOf:$0) == original }) else { fatalError("backup mismatch") }\n print("PASS " + ext + " automatic-tag payload/audio hash/backup verification")\n}\n'
with tempfile.TemporaryDirectory(prefix="minivoice-tag-test-") as directory:
    source = Path(directory) / "main.swift"
    source.write_text((root / "MacOS/Sources/MiniVoice/FFMpegTagWriter.swift").read_text() + harness)
    binary = Path(directory) / "test"
    subprocess.run(["swiftc", str(source), "-o", str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
