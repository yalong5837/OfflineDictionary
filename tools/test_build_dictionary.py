import unittest

from build_dictionary import numbered_to_marks


class PinyinTest(unittest.TestCase):
    def test_tone_marks(self):
        self.assertEqual(numbered_to_marks("ni3 hao3"), "nǐ hǎo")
        self.assertEqual(numbered_to_marks("xue2 xi2"), "xué xí")
        self.assertEqual(numbered_to_marks("gou3"), "gǒu")
        self.assertEqual(numbered_to_marks("lu:4"), "lǜ")
        self.assertEqual(numbered_to_marks("liu2"), "liú")
        self.assertEqual(numbered_to_marks("Bei3 jing1"), "Běi jīng")
        self.assertEqual(numbered_to_marks("ma5"), "ma")
        self.assertEqual(numbered_to_marks("san1 D"), "sān D")


if __name__ == "__main__":
    unittest.main()
