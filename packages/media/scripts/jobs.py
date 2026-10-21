#!/usr/bin/env python3
"""jobs — remote work, from the boards that publish it without a key.

The assistant's job is not only to answer questions but to find the work
worth doing, and to be asked about it. Mercor, Remotive, RemoteOK and
We Work Remotely all publish their listings as plain JSON or RSS, with no
key and no account, so the notch can look for work on its own.

    jobs [--limit N] [--query "terms"]
"""
import json
import re
import urllib.request

UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"


# Where remote work is found. Every one of these is a public feed with
# no key: the assistant can look for work without an account anywhere.
JOB_SOURCES = ("mercor", "remotive", "remoteok", "wwr")

# The AI training platforms: where the work is writing, rating and
# checking for the models. None of them publish a feed — each one wants
# an account — so they are a table instead: where to sign up, what it
# pays, and what they want to see before they let you work.
PLATFORMS = (
    {
        "name": "Outlier",
        "rate": "$15-40/hr",
        "url": "https://outlier.ai/",
        "work": "expert annotation: code, maths, law, medicine",
        "requirements": [
            "a phone number in the US, Canada or the UK",
            "a driving licence or passport, for the identity check",
            "a resume, in English",
            "a PayPal, airtm or Wise account, for the money",
            "a laptop, for the tasks that need a keyboard",
        ],
    },
    {
        "name": "Mercor",
        "rate": "$20-60/hr",
        "url": "https://www.mercor.com/",
        "work": "AI training and evaluation, paid by the project",
        "requirements": [
            "the same phone, licence, resume and payout account",
            "often a degree, or years in a field: engineering, law, medicine",
            "a short introduction, and an interview for the bigger projects",
        ],
    },
    {
        "name": "Handshake AI",
        "rate": "$20-50/hr",
        "url": "https://joinhandshake.com/",
        "work": "AI training tasks: writing, rating and checking answers",
        "requirements": [
            "the same phone, licence, resume and payout account",
            "an onboarding assessment, before any task",
            "a university degree, for many of the roles",
        ],
    },
    {
        "name": "Mindrift",
        "rate": "$15-35/hr",
        "url": "https://mindrift.ai/",
        "work": "expert training work, 20-40 hours a week, many fields",
        "requirements": [
            "the same phone, licence, resume and payout account",
            "a field you actually know, at a professional level",
        ],
    },
    {
        "name": "Appen",
        "rate": "$8-25/hr",
        "url": "https://crowdgen.com/appen-mobile/",
        "work": "search evaluation, data annotation, language tasks",
        "requirements": [
            "the same phone, licence, resume and payout account",
            "a short phone assessment, for some projects",
        ],
    },
    {
        "name": "TELUS Digital",
        "rate": "$10-30/hr",
        "url": "https://www.telusdigital.com/",
        "work": "AI data annotation, through the AI Community",
        "requirements": [
            "the same phone, licence, resume and payout account",
            "a profile questionnaire, and a webcam for some tasks",
        ],
    },
)

# The truth about the table: several of them will not open an account
# outside the US, Canada and the UK, because the phone and the bank have
# to be local. That is their rule, not the notch's to work around — so
# the notch says it plainly and does not pretend otherwise.
GEO_NOTE = ("Several of these want a US, Canadian or UK phone number and a "
            "local payout account, and will not open an account elsewhere. "
            "That is their rule; the notch states it rather than working "
            "around it.")


def _read(url, headers=None, timeout=30):
    request = urllib.request.Request(url, headers=headers or {"User-Agent": UA})
    with urllib.request.urlopen(request, timeout=timeout) as answer:
        return answer.read().decode(errors="replace")


def _jobs_mercor(limit):
    """Mercor's board: the listings are in the page it serves."""
    try:
        page = _read("https://work.mercor.com/explore",
                     {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) Chrome/124.0"})
    except Exception:
        return []
    found = []
    # The listing and its slug sit near each other in the page's payload.
    for match in re.finditer(
            r'"listingId":"([^"]{6,80})"[^{}]{0,400}?"title":"([^"]{6,110})"',
            page):
        ident, title = match.group(1), match.group(2)
        found.append({"title": title.replace("\\u0026", "&"),
                      "company": "",
                      "url": f"https://work.mercor.com/jobs/{ident}",
                      "location": "remote", "salary": "", "source": "mercor",
                      "tags": []})
        if len(found) >= limit:
            break
    return found


def _jobs_remotive(limit):
    try:
        found = json.loads(_read(
            "https://remotive.com/api/remote-jobs?limit=%d" % max(limit, 20)))
    except Exception:
        return []
    out = []
    for job in found.get("jobs", []):
        out.append({"title": job.get("title", ""),
                    "company": job.get("company_name", ""),
                    "url": job.get("url", ""),
                    "location": job.get("candidate_required_location", ""),
                    "salary": job.get("salary", "") or "",
                    "source": "remotive",
                    "tags": (job.get("tags") or [])[:6]})
    return out[:limit]


def _jobs_remoteok(limit):
    try:
        found = json.loads(_read("https://remoteok.com/api"))
    except Exception:
        return []
    out = []
    for job in found if isinstance(found, list) else []:
        if not isinstance(job, dict):
            continue
        slug = job.get("slug", "")
        tags = job.get("tags") or []
        if isinstance(tags, str):
            tags = [tag.strip(" []'\"") for tag in tags.split(",") if tag.strip()]
        out.append({"title": job.get("position") or job.get("title", ""),
                    "company": job.get("company") or job.get("company_name", ""),
                    "url": (f"https://remoteok.com/{slug}" if slug
                            else job.get("url", "")),
                    "location": job.get("location", ""),
                    "salary": (f"{job.get('salary_min')}-{job.get('salary_max')}"
                               if job.get("salary_min") else ""),
                    "source": "remoteok",
                    "tags": list(tags)[:6]})
    return out[:limit]


def _jobs_wwr(limit):
    try:
        feed = _read("https://weworkremotely.com/remote-jobs.rss")
    except Exception:
        return []
    out = []
    for item in re.findall(r"<item>(.*?)</item>", feed, re.S):
        title = re.search(r"<title>(.*?)</title>", item, re.S)
        link = re.search(r"<link>(.*?)</link>", item, re.S)
        company = re.search(r"<(?:dc:)?creator>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</(?:dc:)?creator>",
                            item, re.S)
        if not title:
            continue
        out.append({"title": re.sub(r"<!\[CDATA\[|\]\]>", "",
                                   title.group(1)).strip(),
                    "company": (company.group(1).strip() if company else ""),
                    "url": link.group(1).strip() if link else "",
                    "location": "remote", "salary": "", "source": "wwr",
                    "tags": []})
    return out[:limit]


def jobs(limit=24, query=""):
    """Remote work, from the boards that publish it without a key.

    The assistant's job is not only to answer questions but to find the
    work worth doing, and to be asked about it.
    """
    # Every board gets a turn, so the shelf is a mix and not one board's
    # idea of what remote work is.
    boards = []
    for source in JOB_SOURCES:
        if source == "mercor":
            boards.append(_jobs_mercor(limit))
        elif source == "remotive":
            boards.append(_jobs_remotive(limit))
        elif source == "remoteok":
            boards.append(_jobs_remoteok(limit))
        elif source == "wwr":
            boards.append(_jobs_wwr(limit))
    found = []
    for number in range(max([len(board) for board in boards] or [0])):
        for board in boards:
            if number < len(board):
                found.append(board[number])
    words = [word.lower() for word in query.split() if word]
    if words:
        found = [job for job in found
                 if any(word in (job["title"] + " " + job["company"] + " " +
                                 " ".join(job.get("tags") or [])).lower()
                        for word in words)]
    # The newest first, and no board's copy of the same posting twice.
    seen = set()
    out = []
    for job in found:
        key = (job["title"].lower(), job["company"].lower())
        if key in seen or not job["title"]:
            continue
        seen.add(key)
        out.append(job)
    return out[:limit]


def platforms():
    """The AI training platforms, and what they want before they let you work.

    These are not postings: each one wants an account, so the honest thing
    to offer is the way in, the rate, and the list of things to have ready
    before the sign-up.
    """
    return {
        "note": GEO_NOTE,
        "platforms": [{"name": p["name"], "rate": p["rate"], "url": p["url"],
                       "work": p["work"], "requirements": p["requirements"]}
                      for p in PLATFORMS],
    }
