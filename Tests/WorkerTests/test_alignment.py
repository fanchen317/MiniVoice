import importlib.util
from pathlib import Path
from types import SimpleNamespace as Segment
import unittest

spec = importlib.util.spec_from_file_location("worker", Path(__file__).parents[2] / "Sources/MiniVoice/Resources/align_lyrics.py")
worker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker)


class AlignmentTests(unittest.TestCase):
    def test_collapsed_line_retains_text_as_unmatched(self):
        result = worker.validated_segments(["a", "b", "c"], [Segment(text="a", start=1, end=2), Segment(text="b", start=3, end=3), Segment(text="c", start=4, end=5)], 10)
        self.assertIsNone(result[1]["start"])
        self.assertEqual(result[1]["text"], "b")
        worker.ensure_coverage(result)

    def test_weak_coverage_rejected(self):
        with self.assertRaises(worker.AlignmentFailure):
            worker.ensure_coverage([{"start": None}, {"start": 1}, {"start": None}])

    def test_nonfinite_or_reversed_not_written_as_timestamps(self):
        result = worker.validated_segments(["a", "b", "c"], [Segment(text="a", start=2, end=3), Segment(text="b", start=1, end=2), Segment(text="c", start=float("nan"), end=4)], 10)
        self.assertEqual([line["start"] for line in result], [2, None, None])

    def test_missing_text_is_not_silently_dropped(self):
        with self.assertRaises(worker.AlignmentFailure):
            worker.validated_segments(["a", "b"], [Segment(text="a", start=1, end=2)], 10)
        result = worker.validated_segments(["a"], [Segment(text="different", start=1, end=2)], 10)
        self.assertEqual(result[0], {"text": "a", "start": None, "end": None})

    def test_retry_uses_audio_bounds_and_preserves_unmatched(self):
        class Model:
            def align(self, audio, text, **kwargs):
                self.length = len(audio)
                return Segment(segments=[Segment(text=text, start=0.5, end=1.5)])
        model = Model()
        result = worker.retry_missing(model, [0] * 160000,
                                      [{"text": "a", "start": 1, "end": 2}, {"text": "b", "start": None, "end": None}, {"text": "c", "start": 6, "end": 7}], "en", lambda _: None)
        self.assertEqual(model.length, 4 * 16000)
        self.assertEqual(result[1]["start"], 2.5)
        self.assertEqual(result[1]["end"], 3.5)


if __name__ == "__main__":
    unittest.main()
