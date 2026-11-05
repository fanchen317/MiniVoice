"""Word-mode contract tests: fake measured model rows, never a claimed AI accuracy test."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace as Segment
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("word_worker", Path(__file__).parents[2] / "Sources/MiniVoice/Resources/align_lyrics.py")
worker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker)


def word(text, start, end, probability=0.9):
    return Segment(word=text, start=start, end=end, probability=probability)


class MeasuredWordTests(unittest.TestCase):
    def test_background_word_threads_are_bounded_without_changing_legacy_line_mode(self):
        for value, expected in [("1", 1), ("0", 1), ("99", 4), ("invalid", 2), ("2.5", 2)]:
            with patch.dict(worker.os.environ, {"MINIVOICE_ALIGNMENT_THREADS": value}), patch.object(worker.os, "cpu_count", return_value=8):
                self.assertEqual(worker.alignment_thread_count({"granularity": "word"}), expected)
                self.assertEqual(worker.alignment_thread_count({}), 4)

    def test_measured_tokens_preserve_original_whitespace_without_character_subdivision(self):
        result = worker.validated_words("  hello  世界 ! ", [word("hello", 1.1, 1.8), word(" 世界", 2, 3), word("!", 3, 3.1)], 1, 4)
        self.assertEqual("".join(row["text"] for row in result), "  hello  世界 ! ")
        self.assertEqual([row["text"] for row in result], ["  hello  ", "世界 ", "! "])
        self.assertEqual(result[1]["start"], 2)
        self.assertEqual(result[1]["end"], 3)
        self.assertEqual(len(result), 3)  # 世界 stays one measured model word.

    def test_changed_or_missing_source_characters_reject_entire_line(self):
        for measured in [[word("你号", 1, 2)], [word("你", 1, 2)], [word("你好啊", 1, 2)]]:
            self.assertEqual(worker.validated_words("你好", measured, 1, 3), [])

    def test_low_confidence_or_missing_timing_never_creates_interpolated_words(self):
        for measured in [[word("你好", 1, 2, .2)], [word("你好", 1, 1)], [word("你好", float("nan"), 2)],
                         [word("你好", 0, 2)], [word("你好", 1, 4)], [word("你好", 1, 2, float("nan"))]]:
            self.assertEqual(worker.validated_words("你好", measured, 1, 3), [])
        self.assertEqual(worker.validated_words("你好世界", [word("你好", 1, 2.2), word("世界", 2, 3)], 1, 3), [])

    def test_model_rounding_overlap_is_clamped_but_not_stretched(self):
        result = worker.validated_words("ab", [word("a", 1, 1.5), word("b", 1.49, 2)], 1, 2)
        self.assertEqual(result[1]["start"], 1.5)
        self.assertEqual(result[1]["end"], 2)

    def test_anchor_validation_runs_before_any_inference(self):
        for anchors in [[1], [2, 1], [1, 1], [-1, 2], [1, float("nan")], [1, True], [1, 10]]:
            with self.assertRaises(worker.AlignmentFailure):
                worker.word_alignment_windows(["a", "b"], anchors, 10)

    def test_missing_anchor_uses_model_evidence_between_real_neighboring_anchors(self):
        lines = ["a", "b", "c", "d"]
        coarse = [Segment(text="a", start=0, end=2), Segment(text="b", start=3, end=4),
                  Segment(text="c", start=12, end=13), Segment(text="d", start=14, end=15)]
        windows = worker.word_alignment_windows(lines, [1, None, None, 10], 20, coarse)
        self.assertEqual(windows[0], {"text": "a", "start": 1, "end": 3})
        self.assertEqual(windows[1], {"text": "b", "start": 3, "end": 4})
        self.assertIsNone(windows[2])  # The model placed c beyond the next true anchor.
        self.assertEqual(windows[3]["start"], 10)

    def test_fully_anchored_rows_use_bounded_align_words_and_preserve_line_starts(self):
        class Model:
            def align(self, *_args, **_kwargs):
                raise AssertionError("Known line anchors must not trigger whole-song alignment")

            def align_words(self, audio, windows, **kwargs):
                self.windows, self.kwargs = windows, kwargs
                return Segment(segments=[Segment(text="你好", words=[word("你好", 1.2, 2)]),
                                         Segment(text="世界", words=[word("世界", 4.2, 5)])])
        model = Model()
        result = worker.align_word_rows(model, [0] * 160000,
                                        {"lines": ["你好", "世界"], "anchors": [1, 4], "duration": 10, "language": "zh"}, lambda _: None)
        self.assertEqual(model.windows, [{"text": "你好", "start": 1, "end": 4}, {"text": "世界", "start": 4, "end": 10}])
        self.assertTrue(model.kwargs["normalize_text"])
        self.assertEqual(result[0]["start"], 1)
        self.assertEqual(result[0]["words"][0]["start"], 1.2)
        self.assertEqual(result[1]["end"], 5)

    def test_unreliable_line_keeps_source_anchor_but_has_no_word_timing(self):
        class Model:
            def align_words(self, _audio, _windows, **_kwargs):
                return Segment(segments=[Segment(text="a", words=[word("a", 1.1, 2)]),
                                         Segment(text="b", words=[word("b", 4.1, 5, .1)])])
        result = worker.align_word_rows(Model(), [0] * 160000,
                                        {"lines": ["a", "b"], "anchors": [1, 4], "duration": 10, "language": "en"}, lambda _: None)
        self.assertEqual(result[1], {"text": "b", "start": 4, "end": None, "words": []})

    def test_no_reliable_words_is_failure_not_fabricated_timeline(self):
        class Model:
            def align_words(self, _audio, _windows, **_kwargs):
                return Segment(segments=[Segment(text="a", words=[word("a", 1, 2, .1)])])
        with self.assertRaises(worker.AlignmentFailure):
            worker.align_word_rows(Model(), [0] * 160000,
                                   {"lines": ["a"], "anchors": [1], "duration": 10, "language": "en"}, lambda _: None)


if __name__ == "__main__":
    unittest.main()
