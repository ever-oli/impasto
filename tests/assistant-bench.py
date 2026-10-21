#!/usr/bin/env python3
"""assistant-bench.py — the notch's assistant, scored against Natively's yardstick.

Natively is the free Cluely clone: an Electron overlay that turns a
conversation into notes. Its benchmark is the honest way to ask whether
ours is as good: their tasks, their gold fact sheets, their judge
rubric, our answers.

This runs one of their reference tasks through our assistant and judges
the answer the way they judge theirs — a fact sheet written by a human
analyst, and a score out of ten on each of their dimensions.

    tests/assistant-bench.py --ref <reference.json> --transcript <transcript.txt>
    tests/assistant-bench.py --suite            every task the repo ships

The judge is a model, so it is not a measurement of truth; it is a
measurement of agreement with a human-written fact sheet, which is the
same yardstick Natively uses on itself.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASK = os.path.join(ROOT, "packages/assistant/bin/notch-ask-cli")
BACKEND = os.environ.get("ASK_BACKEND", "opencode")
JUDGE = os.environ.get("BENCH_JUDGE_MODEL", "opencode/glm-5.3-flash-free")

SYSTEM = """You are a meticulous, impartial evaluator of AI-generated notes for
a note-taking product. You will receive (1) a source transcript, (2) a GOLD
reference fact sheet written by a human analyst from that transcript, and (3)
ONE candidate set of notes. Evaluate the notes AS A WHOLE: a fact counts as
retained if it is conveyed correctly anywhere in the notes.

Rules:
- The fact sheet states FINAL values. When the transcript contains
  corrections, the final value is the truth. Reporting a superseded value
  (without clearly marking it as superseded) is a contradiction and a
  numeric/timeline error.
- Items listed under "not_decisions" were only floated or rejected.
  Presenting them as decided/agreed is a critical error.
- Hallucination = any claim not supported by the transcript (invented
  names, numbers, dates, owners, decisions, or conclusions). Check the
  transcript, not just the fact sheet, before calling something
  hallucinated.
- Misattribution (wrong person said/owns something) counts against
  speaker_attribution and factual_accuracy.
- Judge only what is written. Do not reward length for its own sake; do
  not penalize density when every line is substantive. Penalize
  repetition, filler, and irrelevant small talk/distractors under
  conciseness.
- Be consistent and strict. Use the full 1-10 range.

Score anchors (1-10): 10 = flawless; 8 = minor omissions or wording
issues, no material errors; 6 = several important omissions or one
material error; 4 = many important omissions or multiple material errors;
2 = largely wrong or unusable; 1 = empty/garbage.

For fact_checks, give EVERY fact id from the fact sheet exactly one status:
- "present": conveyed correctly with its key qualifiers
- "partial": the gist is there but a key qualifier is missing or vague
- "missing": not conveyed
- "contradicted": the notes state something incompatible

Return ONLY JSON with exactly this shape:
{
  "factual_accuracy": 1-10,
  "important_information_retention": 1-10,
  "hallucination_control": 1-10,
  "action_item_retention": 1-10,
  "decision_retention": 1-10,
  "speaker_attribution": 1-10,
  "numeric_accuracy": 1-10,
  "entity_retention": 1-10,
  "timeline_accuracy": 1-10,
  "conclusion_accuracy": 1-10,
  "structure": 1-10,
  "conciseness": 1-10,
  "readability": 1-10,
  "overall_summary_quality": 1-10,
  "critical_errors": ["..."],
  "missing_important_information": ["..."],
  "hallucinated_information": ["..."],
  "fact_checks": [{"id": "F01", "status": "present|partial|missing|contradicted"}],
  "rationale": "3-6 sentences"
}"""


def ask(question, timeout=900):
    """Our assistant, asked the way the panel asks it."""
    try:
        run = subprocess.run([ASK, "--backend", BACKEND, question],
                             capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return ""
    return (run.stdout or "").strip()


def judge(transcript, reference, notes):
    """The rubric, applied to our notes."""
    facts = [{"id": fact["id"], "statement": fact["statement"],
              "importance": fact.get("importance", "minor")}
             for fact in reference.get("facts", [])]
    sheet = {
        "context": reference.get("context", ""),
        "facts": facts,
        "not_decisions": reference.get("not_decisions", []),
        "summary_must_include": reference.get("summary_must_include", []),
    }
    user = (
        "SOURCE TRANSCRIPT\n" + transcript + "\n\n"
        "GOLD FACT SHEET\n" + json.dumps(sheet, indent=1) + "\n\n"
        "CANDIDATE NOTES\n" + notes + "\n\n"
        "Return only the JSON."
    )
    prompt = SYSTEM + "\n\n" + user
    run = subprocess.run(
        ["opencode", "run", "--model", JUDGE, prompt],
        capture_output=True, text=True, timeout=900,
        env=dict(os.environ,
                 PATH=os.path.expanduser("~/.local/bin") + ":" + os.environ.get("PATH", "")))
    text = (run.stdout or "").strip()
    match = re.search(r"\{.*\}", text, re.S)
    if not match:
        return None
    try:
        return json.loads(match.group(0))
    except ValueError:
        return None


def run_task(reference_path, transcript_path, verbose=False):
    reference = json.load(open(reference_path))
    transcript = open(transcript_path).read()
    who = reference.get("speakers", [{}])[0].get("shown_to_model_as", "the speaker")
    question = (
        "These are the notes of a talk. Write the notes of it: a short "
        "overview, then the points that matter, the decisions and actions "
        "that were made, the open questions, and anything that was "
        "corrected later. Keep it tight and factual.\n\n"
        f"Context: {reference.get('context', '')}\n\n"
        f"--- the talk ---\n{transcript}\n--- end of the talk ---"
    )
    notes = ask(question)
    if not notes:
        return {"id": reference.get("id"), "error": "the assistant did not answer"}
    if verbose:
        print("--- the notes ---\n" + notes[:1500])
    scores = judge(transcript, reference, notes)
    if not scores:
        return {"id": reference.get("id"), "error": "the judge did not answer"}
    return {"id": reference.get("id"), "scores": scores, "notes": notes}


RESULTS = os.path.join(os.environ.get("XDG_STATE_HOME",
                                     os.path.expanduser("~/.local/state")),
                       "notch", "bench-results.json")


def remember(result):
    """Keep the score, so the trend is visible."""
    try:
        os.makedirs(os.path.dirname(RESULTS), exist_ok=True)
        with open(RESULTS) as handle:
            history = json.load(handle)
    except (OSError, ValueError):
        history = []
    history.append({"id": result.get("id"), "when": time.time(),
                    "judge": JUDGE, "backend": BACKEND,
                    "overall": result.get("scores", {}).get("overall_summary_quality"),
                    "average": result.get("average"),
                    "facts": result.get("facts")})
    try:
        with open(RESULTS, "w") as handle:
            json.dump(history[-40:], handle, indent=1)
    except OSError:
        pass
    return history


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ref", help="a Natively reference json")
    parser.add_argument("--transcript", help="the transcript it belongs to")
    parser.add_argument("--suite", action="store_true", help="every task the repo ships")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()

    tasks = []
    if args.suite:
        root = os.environ.get("NATIVELY_BENCH", "")
        if not root:
            print("set NATIVELY_BENCH to the Natively checkout's benchmark folder")
            return 1
        for name in sorted(os.listdir(os.path.join(root, "references"))):
            if not name.endswith(".json"):
                continue
            tasks.append((os.path.join(root, "references", name),
                          os.path.join(root, "transcripts/src", name[:-5] + ".txt")))
    elif args.ref and args.transcript:
        tasks.append((args.ref, args.transcript))
    else:
        parser.print_help()
        return 2

    dimensions = ["factual_accuracy", "important_information_retention",
                  "hallucination_control", "action_item_retention",
                  "decision_retention", "speaker_attribution",
                  "numeric_accuracy", "entity_retention", "timeline_accuracy",
                  "conclusion_accuracy", "structure", "conciseness",
                  "readability", "overall_summary_quality"]
    totals = []
    for reference, transcript in tasks:
        if not (os.path.exists(reference) and os.path.exists(transcript)):
            print(f"· {os.path.basename(reference)}: missing")
            continue
        result = run_task(reference, transcript, args.verbose)
        name = result.get("id", os.path.basename(reference))
        if result.get("error"):
            print(f"· {name}: {result['error']}")
            continue
        scores = result["scores"]
        got = {status: 0 for status in ("present", "partial", "missing", "contradicted")}
        for check in scores.get("fact_checks", []):
            if check.get("status") in got:
                got[check["status"]] += 1
        print(f"· {name}")
        for dimension in dimensions:
            if dimension in scores:
                print(f"    {dimension:38} {scores[dimension]}")
        print(f"    facts: {got}")
        average = sum(scores.get(d, 0) for d in dimensions) / len(dimensions)
        result["average"] = round(average, 2)
        result["facts"] = got
        print(f"    overall: {scores.get('overall_summary_quality')} "
              f"(dimensions average {average:.1f})")
        if scores.get("critical_errors"):
            print(f"    critical: {scores['critical_errors'][:3]}")
        print(f"    why: {scores.get('rationale', '')[:400]}")
        totals.append(scores)
        remember(result)
    if totals:
        average = sum(sum(s.get(d, 0) for d in dimensions) / len(dimensions)
                      for s in totals) / len(totals)
        overall = sum(s.get("overall_summary_quality", 0) for s in totals) / len(totals)
        print(f"\n{len(totals)} task(s): the average of the dimensions is "
              f"{average:.1f}/10, the overall {overall:.1f}/10")
        print(f"answered by the {BACKEND} backend, judged by {JUDGE}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
