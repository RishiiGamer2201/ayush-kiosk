"""Gemini on Vertex AI, in the project's own region, as the open-vocabulary extractor.

Same job as LocalLLMClinicalExtractor: read one utterance and fill in the fields the heuristic
matcher has no phrase for. It sits behind HybridClinicalExtractor exactly as the Ollama model
does, so its output is grounded against the transcript and can only add to what the
deterministic matcher found, never override it.

Vertex rather than the Gemini developer API: the intake API already runs its reader there
(asia-south1, zero data retention), and one project, one region and one set of service-account
credentials is the whole story a hospital has to be told about where patient speech goes.

Never raises. A network fault, a quota refusal or a malformed answer degrades to an all-null
update; the heuristic fields still stand and the turn goes on.
"""

from __future__ import annotations

import asyncio
import json
import logging
from pathlib import Path

from medikiosk.models import ClinicalUpdate

logger = logging.getLogger(__name__)

INSTRUCTIONS = """
You extract explicitly stated clinical intake facts from one patient utterance, which may be in
any Indian language or a mix. Return only the supplied JSON schema. Do not diagnose, infer
unstated facts, or convert uncertainty into certainty. A denial such as "no vomiting" is false;
absence of a mention is null. Preserve the complaint in short neutral English words. Severity is
only a 0-10 number if the speaker explicitly says one. Evidence must contain short exact
fragments from the utterance supporting the extracted values. This is intake support, not
medical advice.
""".strip()

EMPTY = ClinicalUpdate(
    complaint=None,
    duration=None,
    onset=None,
    severity=None,
    vomiting=None,
    fever=None,
    breathlessness=None,
    chest_pain=None,
    pain_radiation=None,
    sweating=None,
    active_bleeding=None,
    altered_consciousness=None,
    one_sided_weakness=None,
    speech_difficulty=None,
    pregnancy_possible=None,
    age_years=None,
    medications=[],
    allergies=[],
    evidence=[],
)


class GeminiClinicalExtractor:
    def __init__(
        self,
        project: str,
        location: str = "asia-south1",
        model: str = "gemini-3.5-flash",
        credentials_path: Path | None = None,
        timeout: float = 20.0,
    ) -> None:
        # Imported here: the SDK pulls in google-auth and friends, and an offline kiosk that never
        # configures Vertex should not pay for it at startup.
        from google import genai
        from google.genai import types

        credentials = None
        if credentials_path is not None:
            from google.oauth2 import service_account

            credentials = service_account.Credentials.from_service_account_file(
                str(Path(credentials_path).expanduser()),
                scopes=["https://www.googleapis.com/auth/cloud-platform"],
            )
        self.client = genai.Client(
            vertexai=True,
            project=project,
            location=location,
            credentials=credentials,
            http_options=types.HttpOptions(timeout=int(timeout * 1000)),
        )
        self.model = model
        self.timeout = timeout
        self._config = types.GenerateContentConfig(
            system_instruction=INSTRUCTIONS,
            response_mime_type="application/json",
            response_schema=ClinicalUpdate,
            temperature=0.0,
            max_output_tokens=1200,
            # No thinking: this is a fill-in-the-schema task, and on the Jetson the model spent
            # 1149 thinking tokens of a 1200 budget and returned JSON cut off mid-field.
            thinking_config=types.ThinkingConfig(thinking_budget=0),
            # No tools are offered, and the SDK warns on every async call unless told so.
            automatic_function_calling=types.AutomaticFunctionCallingConfig(disable=True),
        )

    def health(self) -> bool:
        """Configured is healthy. The first real call finds out about the network, and a failed
        call is already an all-null update rather than a broken turn."""

        return True

    async def extract(self, transcript: str) -> ClinicalUpdate:
        try:
            response = await asyncio.wait_for(
                self.client.aio.models.generate_content(
                    model=self.model, contents=transcript, config=self._config
                ),
                timeout=self.timeout,
            )
            return ClinicalUpdate.model_validate_json(response.text or "")
        except Exception as error:  # noqa: BLE001 - one bad turn must not take the intake down
            failure = f"{type(error).__name__}: {error}"
            logger.warning(json.dumps({"event": "gemini_extract_failed", "failure": failure}))
            return EMPTY.model_copy(deep=True)
