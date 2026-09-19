from collections.abc import Container

from medikiosk.clinical.questions import QUESTIONS
from medikiosk.models import PatientState, QuestionSpec


class ClinicalStateMachine:
    """Chooses the next missing intake field without delegating safety to an LLM."""

    COMMON_ORDER = (
        "ask_complaint",
        "ask_duration",
        "ask_severity",
    )
    CHEST_ORDER = (
        "ask_breathlessness",
        "ask_radiation",
        "ask_sweating",
    )
    ABDOMINAL_ORDER = (
        "ask_vomiting",
        "ask_fever",
        "ask_bleeding",
    )
    GENERAL_ORDER = (
        "ask_breathlessness",
        "ask_fever",
        "ask_vomiting",
        "ask_bleeding",
    )
    # Jaundice only, for the filmed demo run. No red-flag questions, so the emergency alert
    # cannot fire - deliberate for filming, and the reason this is selected by a setting rather
    # than replacing the general orders above.
    JAUNDICE_ORDER = (
        "ask_yellow_eyes",
        "ask_dark_urine",
        "ask_appetite_loss",
        "ask_fever",
    )
    FINAL_ORDER = ("ask_age",)

    def __init__(self, question_set: str = "general") -> None:
        self.question_set = question_set

    def next_question(
        self,
        state: PatientState,
        skip: Container[str] = (),
    ) -> QuestionSpec | None:
        """Next required field. `skip` holds questions already asked without a usable answer."""

        complaint = (state.complaint or "").lower()
        ordered = list(self.COMMON_ORDER)
        if self.question_set == "jaundice_demo":
            ordered.extend(self.JAUNDICE_ORDER)
            ordered.extend(self.FINAL_ORDER)
            for question_id in ordered:
                if question_id in skip:
                    continue
                question = QUESTIONS[question_id]
                if getattr(state, question.target_field) is None:
                    return question
            return None
        if any(term in complaint for term in ("chest", "सीने", "छाती")):
            ordered.extend(self.CHEST_ORDER)
        elif any(term in complaint for term in ("abdominal", "stomach", "belly", "पेट")):
            ordered.extend(self.ABDOMINAL_ORDER)
        else:
            ordered.extend(self.GENERAL_ORDER)
        ordered.extend(self.FINAL_ORDER)

        for question_id in ordered:
            if question_id in skip:
                continue
            question = QUESTIONS[question_id]
            if getattr(state, question.target_field) is None:
                return question
        return None
