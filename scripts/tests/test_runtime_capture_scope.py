import importlib.util
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
spec = importlib.util.spec_from_file_location('runtime_capture', Path(__file__).resolve().parents[1] / 'capture-runtime-baseline.py')
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)

class RuntimeCaptureScopeTest(unittest.TestCase):
    def test_default_still_requires_all_fifty_samples(self):
        keys = capture.expected_sample_keys()
        self.assertEqual(len(keys), 50)
        self.assertEqual({key[0] for key in keys}, set(capture.DEFAULT_SCENARIOS))
        self.assertIn(('watchlist_400', 'warm', 5), keys)

    def test_tv_only_requires_both_cache_conditions_and_five_repetitions(self):
        keys = capture.expected_sample_keys('tv_detail')
        self.assertEqual(len(keys), 10)
        self.assertEqual({key[0] for key in keys}, {'tv_detail'})
        for cache in ('cold', 'warm'):
            self.assertEqual({key[2] for key in keys if key[1] == cache}, {1, 2, 3, 4, 5})

    def test_profile_is_opt_in_and_requires_ten_samples(self):
        self.assertEqual(len(capture.expected_sample_keys('profile')), 10)
        self.assertNotIn('profile', {key[0] for key in capture.expected_sample_keys()})

    def test_friend_profile_is_opt_in_and_requires_ten_samples(self):
        self.assertEqual(len(capture.expected_sample_keys('friend_profile')), 10)
        self.assertNotIn('friend_profile', {key[0] for key in capture.expected_sample_keys()})

    def test_social_is_opt_in_and_requires_ten_samples(self):
        self.assertEqual(len(capture.expected_sample_keys('social')), 10)
        self.assertNotIn('social', {key[0] for key in capture.expected_sample_keys()})

    def test_watch_requests_is_opt_in_and_requires_ten_samples(self):
        self.assertEqual(len(capture.expected_sample_keys('watch_requests')), 10)
        self.assertNotIn('watch_requests', {key[0] for key in capture.expected_sample_keys()})

    def test_group_watch_plan_is_opt_in_with_both_cache_conditions(self):
        keys = capture.expected_sample_keys('group_watch_plan')
        self.assertEqual(len(keys), 10)
        self.assertNotIn('group_watch_plan', {key[0] for key in capture.expected_sample_keys()})
        for cache in ('cold', 'warm'):
            self.assertEqual({key[2] for key in keys if key[1] == cache}, {1, 2, 3, 4, 5})

    def test_composer_is_opt_in_with_ten_samples(self):
        keys=capture.expected_sample_keys('watch_composer')
        self.assertEqual(len(keys),10)
        self.assertNotIn('watch_composer',{key[0] for key in capture.expected_sample_keys()})

    def test_insights_is_opt_in_with_ten_samples(self):
        self.assertEqual(len(capture.expected_sample_keys('group_insights')), 10)
        self.assertNotIn('group_insights', {key[0] for key in capture.expected_sample_keys()})

    def test_search_is_opt_in_with_ten_samples(self):
        self.assertEqual(len(capture.expected_sample_keys('search')), 10)
        self.assertNotIn('search', {key[0] for key in capture.expected_sample_keys()})

    def test_unknown_scope_cannot_silently_capture_nothing(self):
        with self.assertRaises(ValueError):
            capture.expected_sample_keys('tv')

    def test_person_detail_is_opt_in_with_both_cache_conditions(self):
        keys = capture.expected_sample_keys('person_detail')
        self.assertEqual(len(keys), 10)
        self.assertEqual({key[0] for key in keys}, {'person_detail'})
        self.assertNotIn('person_detail', {key[0] for key in capture.expected_sample_keys()})
        for cache in ('cold', 'warm'):
            self.assertEqual({key[2] for key in keys if key[1] == cache}, {1, 2, 3, 4, 5})

if __name__ == '__main__':
    unittest.main()
