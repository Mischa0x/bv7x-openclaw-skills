"""
Unit tests for starter-agent.py decision logic.

Tests the `decide()` function in isolation and the registration
payload format without hitting the live API.

Run: pytest tests/test_starter_agent.py -v
"""

import json
import sys
import os
import pytest

# Add examples/ to path so we can import the module
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'examples'))

# We need to patch 'requests' before importing since the module imports it at top level
import types
mock_requests = types.ModuleType('requests')
sys.modules['requests'] = mock_requests

import importlib
starter = importlib.import_module('starter-agent')


# ============================================
# decide() — Strategy Logic
# ============================================

class TestDecide:
    """Test the oracle-tailing / oracle-fading decision logic."""

    def test_tails_oracle_on_high_confidence_up(self):
        signal = {'parsimonious': {'direction': 'UP', 'confidence': 0.65, 'action': 'BUY'}}
        assert starter.decide(signal) == 'UP'

    def test_tails_oracle_on_high_confidence_down(self):
        signal = {'parsimonious': {'direction': 'DOWN', 'confidence': 0.60, 'action': 'SELL'}}
        assert starter.decide(signal) == 'DOWN'

    def test_tails_at_exact_threshold_055(self):
        signal = {'parsimonious': {'direction': 'UP', 'confidence': 0.55, 'action': 'BUY'}}
        assert starter.decide(signal) == 'UP'

    def test_fades_oracle_on_low_confidence_up(self):
        """Low confidence UP → agent predicts DOWN (contrarian)."""
        signal = {'parsimonious': {'direction': 'UP', 'confidence': 0.40, 'action': 'WEAK_BUY'}}
        assert starter.decide(signal) == 'DOWN'

    def test_fades_oracle_on_low_confidence_down(self):
        """Low confidence DOWN → agent predicts UP (contrarian)."""
        signal = {'parsimonious': {'direction': 'DOWN', 'confidence': 0.42, 'action': 'SELL'}}
        assert starter.decide(signal) == 'UP'

    def test_skips_on_mid_confidence(self):
        """Confidence 0.45-0.55 (exclusive on both ends) → no conviction."""
        signal = {'parsimonious': {'direction': 'UP', 'confidence': 0.50, 'action': 'HOLD'}}
        assert starter.decide(signal) is None

    def test_skips_at_exact_045(self):
        """Confidence exactly 0.45 → falls in mid range, skips."""
        signal = {'parsimonious': {'direction': 'UP', 'confidence': 0.45, 'action': 'BUY'}}
        assert starter.decide(signal) is None

    def test_skips_on_neutral_direction(self):
        """NEUTRAL direction → no prediction even with high confidence."""
        signal = {'parsimonious': {'direction': 'NEUTRAL', 'confidence': 0.70, 'action': 'HOLD'}}
        assert starter.decide(signal) is None

    def test_skips_on_neutral_low_confidence(self):
        """NEUTRAL + low confidence → still no bet (direction not UP/DOWN)."""
        signal = {'parsimonious': {'direction': 'NEUTRAL', 'confidence': 0.30, 'action': 'HOLD'}}
        assert starter.decide(signal) is None

    def test_returns_none_when_no_parsimonious(self):
        signal = {}
        assert starter.decide(signal) is None

    def test_returns_none_when_parsimonious_is_none(self):
        signal = {'parsimonious': None}
        assert starter.decide(signal) is None

    def test_handles_missing_confidence(self):
        """Missing confidence defaults to 0 → low confidence → fade."""
        signal = {'parsimonious': {'direction': 'UP', 'action': 'BUY'}}
        # confidence defaults to 0, which is < 0.45, direction is UP → fade to DOWN
        assert starter.decide(signal) == 'DOWN'

    def test_very_high_confidence(self):
        signal = {'parsimonious': {'direction': 'DOWN', 'confidence': 0.95, 'action': 'STRONG_SELL'}}
        assert starter.decide(signal) == 'DOWN'

    def test_zero_confidence(self):
        """Zero confidence → fade the oracle."""
        signal = {'parsimonious': {'direction': 'DOWN', 'confidence': 0.0, 'action': 'SELL'}}
        assert starter.decide(signal) == 'UP'


# ============================================
# Config persistence
# ============================================

class TestConfig:
    """Test load/save config round-trip."""

    def test_load_empty_config(self, tmp_path, monkeypatch):
        fake_config = tmp_path / '.bv7x-agent-config.json'
        monkeypatch.setattr(starter, 'CONFIG_FILE', fake_config)
        assert starter.load_config() == {}

    def test_save_and_load_config(self, tmp_path, monkeypatch):
        fake_config = tmp_path / '.bv7x-agent-config.json'
        monkeypatch.setattr(starter, 'CONFIG_FILE', fake_config)

        config = {'agent_id': 'agent_abc123', 'api_key': 'bv7x_testkey', 'name': 'test'}
        starter.save_config(config)

        loaded = starter.load_config()
        assert loaded['agent_id'] == 'agent_abc123'
        assert loaded['api_key'] == 'bv7x_testkey'
        assert loaded['name'] == 'test'


# ============================================
# Registration payload format
# ============================================

class TestRegistrationPayload:
    """Verify the registration payload matches what the API expects."""

    def test_register_constructs_correct_payload(self, monkeypatch):
        """Verify register() sends the right JSON to the API."""
        captured = {}

        class MockResponse:
            def json(self):
                return {
                    'success': True,
                    'agent_id': 'agent_test123',
                    'api_key': 'bv7x_testkey123',
                    'name': 'test-agent',
                    'welcome_bonus': '8M $BV7X'
                }

        def mock_post(url, json=None):
            captured['url'] = url
            captured['json'] = json
            return MockResponse()

        mock_requests.post = mock_post

        # Patch CONFIG_FILE to temp
        import tempfile
        tmp = tempfile.mktemp(suffix='.json')
        monkeypatch.setattr(starter, 'CONFIG_FILE', type(starter.CONFIG_FILE)(tmp))

        result = starter.register('test-agent', '0x' + 'a' * 40, 'my-model', 'my-strategy')

        assert 'arena/register' in captured['url']
        assert captured['json']['name'] == 'test-agent'
        assert captured['json']['wallet_address'] == '0x' + 'a' * 40
        assert captured['json']['model'] == 'my-model'
        assert captured['json']['strategy'] == 'my-strategy'
        assert result['agent_id'] == 'agent_test123'

        # Cleanup
        try:
            os.unlink(tmp)
        except OSError:
            pass
