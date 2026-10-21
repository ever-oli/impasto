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
