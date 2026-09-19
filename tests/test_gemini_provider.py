"""Gemini on Vertex fills in what the heuristic matcher has no phrase for, and never breaks a turn."""

import asyncio

import pytest

from medikiosk.clinical.heuristic import HeuristicClinicalExtractor
from medikiosk.clinical.hybrid import HybridClinicalExtractor
from medikiosk.config import Settings
from medikiosk.providers.gemini_provider import EMPTY, GeminiClinicalExtractor


class _Refusing:
    class aio:
        class models:
            @staticmethod
            async def generate_content(**_kwargs):
                raise ConnectionError("no route to asia-south1")


def _offline_extractor() -> GeminiClinicalExtractor:
    extractor = GeminiClinicalExtractor.__new__(GeminiClinicalExtractor)
    extractor.client = _Refusing()
    extractor.model = "gemini-3.5-flash"
    extractor.timeout = 1.0
    extractor._config = None
    return extractor


def test_a_failed_call_is_an_empty_update_not_an_exception() -> None:
    update = asyncio.run(_offline_extractor().extract("sugar badh gayi hai"))
    assert update == EMPTY


def test_the_heuristic_fields_survive_a_vertex_outage() -> None:
    hybrid = HybridClinicalExtractor(HeuristicClinicalExtractor(), _offline_extractor())
    update = asyncio.run(hybrid.extract("chest pain since two days, no vomiting"))
    assert update.chest_pain is True
    assert update.vomiting is False


@pytest.mark.parametrize(
    ("provider", "project", "configured"),
    [("vertex", "medikiosk-sih-2026", True), ("vertex", None, False), ("ollama", "medikiosk-sih-2026", False)],
)
def test_gemini_is_an_explicit_choice_not_a_key_lying_around(provider, project, configured) -> None:
    settings = Settings(clinical_llm_provider=provider, vertex_project=project, _env_file=None)
    assert settings.gemini_configured is configured
