"""The order the kiosk runs in for a filmed demo.

The product default is unchanged and covered elsewhere. These pin the parts the demo settings
move, so turning them on for a deployment cannot quietly drift from what was asked for.
"""

import pytest

from medikiosk.clinical.state_machine import ClinicalStateMachine
from medikiosk.kiosk.flow import KioskFlow, Stage
from medikiosk.models import PatientState


def consented(**kwargs) -> KioskFlow:
    flow = KioskFlow(demo_flow=True, **kwargs)
    flow.action("choose", "en")
    flow.action("choose", "self")
    flow.action("choose", "yes")
    return flow


def test_consent_leads_to_the_vitals_notice_not_the_form() -> None:
    # The measurement needs the whole intake to run in, so the notice comes first.
    assert consented().stage is Stage.VITALS


def test_acknowledging_the_notice_starts_the_measurement_and_moves_on() -> None:
    flow = consented()
    assert flow.action("done") == "measure_background"
    assert flow.stage is Stage.REGISTRATION


def test_the_patient_cannot_skip_their_abha() -> None:
    flow = consented()
    flow.action("done")
    for field in ("Rishii", "18", "male"):
        flow.action("answer", field)
    assert flow.stage is Stage.ABHA
    with pytest.raises(ValueError, match="ABHA number is required"):
        flow.action("skip")


def test_a_given_abha_leads_straight_to_the_problem_with_no_service_choice() -> None:
    flow = consented()
    flow.action("done")
    for field in ("Rishii", "18", "male"):
        flow.action("answer", field)
    flow.action("answer", "12345678901234")
    assert flow.stage is Stage.INTERVIEW


def test_prakriti_is_asked_when_the_record_has_none() -> None:
    flow = consented()
    flow.stage = Stage.INTERVIEW
    flow.complete_interview()
    assert flow.stage in {Stage.AYURVEDA, Stage.PRAKRITI}


def test_prakriti_is_skipped_when_the_abha_already_carries_one() -> None:
    flow = consented(prakriti_on_file=True)
    flow.stage = Stage.INTERVIEW
    flow.complete_interview()
    # Straight on to documents, and the patient is never asked to fill it again.
    assert flow.stage is Stage.CONSENT
    assert flow.prakriti_previously_filled is True


def test_the_patient_is_never_asked_whether_they_filled_it_before() -> None:
    assert consented()._previous_question_pending is False


def test_a_scanned_document_does_not_trap_the_patient_on_the_page() -> None:
    flow = consented()
    flow.stage = Stage.DOCUMENTS
    flow.document_preview = {"capture_id": "abc", "lines": ["something"]}
    flow.action("done")
    assert flow.stage is Stage.REVIEW


def test_the_demo_interview_asks_about_jaundice_and_leaves_out_the_red_flags() -> None:
    machine = ClinicalStateMachine("jaundice_demo")
    state = PatientState(complaint="yellow eyes", duration="3 days", severity=5)
    asked = []
    while (question := machine.next_question(state, skip=asked)) is not None:
        asked.append(question.id)
        setattr(state, question.target_field, 1 if question.target_field == "age_years" else True)
    assert "ask_yellow_eyes" in asked
    assert "ask_dark_urine" in asked
    assert "ask_appetite_loss" in asked
    # Deliberately absent, which is why this set is selected by a setting and not the default.
    assert "ask_bleeding" not in asked
    assert "ask_breathlessness" not in asked


def test_the_general_set_still_asks_the_red_flag_questions() -> None:
    machine = ClinicalStateMachine()
    state = PatientState(complaint="stomach pain", duration="2 days", severity=5)
    asked = []
    while (question := machine.next_question(state, skip=asked)) is not None:
        asked.append(question.id)
        setattr(state, question.target_field, 1 if question.target_field == "age_years" else True)
    assert "ask_bleeding" in asked


def test_the_setting_reaches_the_machine_that_picks_the_questions() -> None:
    # The set was implemented and never passed through: the live kiosk asked about breathing in
    # a jaundice demo. This is the seam it fell through.
    from medikiosk.app import _clinical_session
    from medikiosk.config import Settings

    session = _clinical_session(Settings(question_set="jaundice_demo", _env_file=None), None)
    assert session.state_machine.question_set == "jaundice_demo"


def test_giving_an_abha_in_the_demo_permits_the_lookup_of_earlier_visits_here() -> None:
    flow = consented()
    flow.action("done")
    for field in ("Rishii", "18", "male"):
        flow.action("answer", field)
    assert flow.consent.allows("history_linkage") is False
    flow.action("answer", "rishiisingh2201@abdm")
    assert flow.abha_number == "rishiisingh2201@abdm"
    assert flow.consent.allows("history_linkage") is True


def test_a_saved_visit_carries_the_prakriti_the_next_visit_checks(tmp_path) -> None:
    from cryptography.fernet import Fernet

    from medikiosk.app import _prakriti_on_file
    from medikiosk.kiosk.abha import VisitRecords

    records = VisitRecords(tmp_path / "visits.db", Fernet.generate_key().decode())
    assert _prakriti_on_file(records, "91475812575474") is False
    records.save("91-4758-1257-5474", {"encounter_id": "e1", "prakriti": {"complete": True}})
    # The same patient, whichever way the number was written.
    assert _prakriti_on_file(records, "91475812575474") is True


def test_the_lookup_runs_when_the_abha_is_given_and_skips_prakriti_if_one_is_on_file() -> None:
    def history(abha: str) -> list[dict]:
        return [{"complaint": "fever", "prakriti": {"complete": True}}] if abha == "91475812575474" else []

    flow = KioskFlow(demo_flow=True, visit_history=history)
    flow.action("choose", "en")
    flow.action("choose", "self")
    flow.action("choose", "yes")
    flow.action("done")
    for field in ("Rishii", "18", "male"):
        flow.action("answer", field)
    assert flow.prakriti_on_file is False
    flow.action("answer", "91-4758-1257-5474")
    assert flow.prakriti_on_file is True
    assert flow.past_visits[0]["complaint"] == "fever"
    flow.complete_interview()
    assert flow.stage is Stage.CONSENT  # documents permission, no questionnaire


def test_every_yes_no_question_binds_a_tapped_yes() -> None:
    # The seam the jaundice questions fell through: a question whose field is not in the
    # direct-answer table gets its "yes" filed as unresolved, twice, and is then skipped.
    from medikiosk.clinical.answers import direct_answer
    from medikiosk.clinical.questions import QUESTIONS
    from medikiosk.models import PatientState

    fields = PatientState.model_fields
    for question in QUESTIONS.values():
        if fields[question.target_field].annotation == (bool | None):
            assert direct_answer(question, "yes", "en") == {question.target_field: True}, question.id
            assert direct_answer(question, "नहीं", "hi") == {question.target_field: False}, question.id


def test_a_tapped_yes_to_a_jaundice_question_is_saved_and_moves_the_interview_on() -> None:
    import asyncio

    from medikiosk.app import _clinical_session
    from medikiosk.clinical.questions import QUESTIONS
    from medikiosk.config import Settings

    async def run():
        session = _clinical_session(Settings(question_set="jaundice_demo", _env_file=None), None)
        await session.process_transcript("yellow since three days", "en", asked=QUESTIONS["ask_complaint"], skip=[])
        await session.process_transcript("4", "en", asked=QUESTIONS["ask_severity"], skip=[])
        result = await session.process_transcript("yes", "en", asked=QUESTIONS["ask_yellow_eyes"], skip=[])
        assert result.state.yellow_eyes is True
        assert result.next_question_id == "ask_dark_urine"
        result = await session.process_transcript("no", "en", asked=QUESTIONS["ask_dark_urine"], skip=[])
        assert result.state.dark_urine is False
        assert result.next_question_id == "ask_appetite_loss"

    asyncio.run(run())


def test_yellow_eyes_is_the_complaint_even_when_the_body_map_named_the_head() -> None:
    import asyncio

    from medikiosk.clinical.heuristic import HeuristicClinicalExtractor

    update = asyncio.run(
        HeuristicClinicalExtractor().extract("head / eyes / ears yellow since three days and dark urine")
    )
    assert update.complaint == "jaundice (yellowing)"


def test_a_camera_reading_outside_physiology_is_not_a_reading() -> None:
    flow = consented()
    flow.record_vitals(196.0, True, "ok", 6.0, True)
    assert flow.vitals["confident"] is False
    assert flow.vitals["breath_confident"] is False
    heart = next(a for a in flow.answers if a["id"] == "vitals.heart_rate")
    assert heart["status"] == "unresolved"
    assert "camera" not in heart["question"].lower()  # named as a reading, not an instruction


def test_a_camera_reading_is_shown_on_the_review_but_not_offered_for_editing() -> None:
    from medikiosk.models import PatientState

    flow = consented()
    flow.record_vitals(72.0, True, "ok")
    flow.stage = Stage.REVIEW
    rows = {row["id"]: row for row in flow.screen(PatientState())["review"]}
    assert rows["vitals.heart_rate"]["editable"] is False
    with pytest.raises(ValueError, match="camera reading"):
        flow.action("edit", "vitals.heart_rate")
