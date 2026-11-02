from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
TRACE = ROOT / "F-B-145-TRACEABILITY.md"
ROW = re.compile(r"^\| (B-\d{3}) \|")
FILE_ANCHOR = re.compile(
    r"(?<![A-Za-z0-9_./*-])(?:[A-Za-z0-9_./*-]+\.(?:swift|py|md|html|yml|yaml|json|plist|png))(?:\:[A-Za-z0-9_.]+)?"
)
NAMED_TEST_ANCHOR = re.compile(
    r"(?P<path>[A-Za-z0-9_./*-]+\.(?:swift|py)):(?P<methods>test[A-Za-z0-9_]+(?:,test[A-Za-z0-9_]+)*)"
)


class TraceabilityContractTests(unittest.TestCase):
    def setUp(self):
        self.lines = TRACE.read_text(encoding="utf-8").splitlines()
        self.rows = [line for line in self.lines if ROW.match(line)]

    def test_traceability_rows_are_unique_contiguous_and_keep_all_columns(self):
        ids = [ROW.match(line).group(1) for line in self.rows]
        self.assertEqual(len(ids), 145)
        self.assertEqual(ids, [f"B-{number:03d}" for number in range(1, 146)])
        for line in self.rows:
            self.assertEqual(len(line.split("|")[1:-1]), 13, line)

    def test_explicit_source_and_test_file_anchors_exist(self):
        missing = []
        for line in self.rows:
            cells = [cell.strip() for cell in line.split("|")[1:-1]]
            requirement_id = cells[0]
            for column_index in (8, 9):
                for match in FILE_ANCHOR.finditer(cells[column_index]):
                    anchor = match.group(0).split(":", 1)[0]
                    path = ROOT / anchor
                    if "*" in anchor:
                        path = path.parent
                    if not path.exists():
                        missing.append(f"{requirement_id}: {anchor}")
        self.assertEqual(missing, [])

    def test_named_test_method_anchors_exist_in_the_referenced_files(self):
        missing = []
        checked = 0
        for line in self.rows:
            cells = [cell.strip() for cell in line.split("|")[1:-1]]
            requirement_id = cells[0]
            for match in NAMED_TEST_ANCHOR.finditer(cells[9]):
                path = ROOT / match.group("path")
                source = path.read_text(encoding="utf-8") if path.is_file() else ""
                for method in match.group("methods").split(","):
                    checked += 1
                    definition = re.compile(
                        rf"(?m)^\s*(?:func|(?:async\s+)?def)\s+{re.escape(method)}\s*\("
                    )
                    if not definition.search(source):
                        missing.append(f"{requirement_id}: {path.relative_to(ROOT)}:{method}")
        self.assertGreater(checked, 0, "Traceability table has no explicit test-method anchors")
        self.assertEqual(missing, [])


if __name__ == "__main__":
    unittest.main()
