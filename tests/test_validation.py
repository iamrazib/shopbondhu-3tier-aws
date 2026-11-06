"""API validation tests; database is not needed for these rejection paths."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'backend'))
from app import app


class InputValidationTests(unittest.TestCase):
    def setUp(self):
        self.client = app.test_client()

    def test_title_missing(self):
        result = self.client.post('/api/tasks', json={})
        self.assertEqual(result.status_code, 400)

    def test_title_too_long(self):
        result = self.client.post('/api/tasks', json={'title': 'x' * 151})
        self.assertEqual(result.status_code, 400)

    def test_invalid_completed(self):
        result = self.client.patch('/api/tasks/1', json={'completed': 'yes'})
        self.assertEqual(result.status_code, 400)

    def test_json_array_rejected(self):
        result = self.client.post('/api/tasks', json=['hello'])
        self.assertEqual(result.status_code, 400)


if __name__ == '__main__':
    unittest.main()
