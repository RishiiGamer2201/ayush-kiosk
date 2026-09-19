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
