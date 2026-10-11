---
name: muse-linkedin-learning
description: >
  Use Muse together with LinkedIn Learning as a study system: turn a
  learning goal into a short list of candidate courses, convert a chosen
  course's syllabus and material into mechanism-level study notes and
  drills (flashcards, self-quizzes, worked exercises), and track progress
  across sessions in a durable local file. Use when the user asks to
  "learn X with LinkedIn Learning", "find me a course on...", "make study
  notes/drills from this course", "quiz me on what I watched", or wants
  to resume a LinkedIn Learning study track. Pairs with goal and
  certification study workflows (e.g. Salesforce cert prep).
license: Apache-2.0
compatibility: >
  Workflow skill. LinkedIn Learning has no personal-account API Muse
  can call: course playback, enrollment, and progress inside LinkedIn
  Learning happen in the user's own signed-in browser. Muse works from
  course pages/URLs the user shares, public course descriptions, and
  notes or transcripts the user provides in-session. Never ask for
  LinkedIn credentials; never download course videos (against the
  service's terms).
metadata:
  app: linkedin-learning
  role: study-workflow
allowed-tools: Read Edit Bash
---

# Muse + LinkedIn Learning

LinkedIn Learning supplies the lectures; Muse supplies everything around
them that makes lectures stick: selection against a goal, notes that
teach the mechanism, drills that expose gaps, and a memory of where the
study left off. This skill is a workflow authored for Matt — it describes
a way of working, not an integration LinkedIn offers.

## The four phases

### 1. Goal → shortlist

1. State the goal as an outcome, not a topic: "pass Platform Developer I"
   or "be able to review a JWT implementation", not "learn security".
2. Find candidates: search LinkedIn Learning's public catalog pages (web
   search / the user browsing their signed-in catalog). For each
   candidate capture: title, author, duration, level, syllabus
   (chapter list), and last-updated date if shown.
3. Cut to a shortlist of at most three, ranked by: syllabus overlap with
   the goal, level fit (skip intro material he can already test out of),
   and recency for fast-moving topics. Present the tradeoff in one line
   each; the user picks. Enrollment is the user's click.

### 2. Course → study notes

Work one course section at a time, from material actually available:
the syllabus, the user's notes, or transcripts/exercise files the user
provides in-session. For each section produce a notes file that:

- opens in plain language, then goes to mechanism depth (the house
  style — never label it "ELI5"),
- uses collapsible `<details>`/`<summary>` sections so the file stays
  scannable (standing markdown rule),
- ends with "exam/job gotchas": the distinctions the material is really
  testing,
- links claims back to the course section they came from.

Store notes under `~/workspace/learning/<track>/<course-slug>.md` unless
the track already has a home (e.g. Salesforce study material lives with
the Salesforce program files).

### 3. Notes → drills

From each notes file, generate drills in three forms, hardest last:

- **Flashcards** — term → mechanism, not term → definition.
- **Self-quiz** — multiple-choice or short-answer with an answer key
  kept in a collapsed section so the file is usable without Muse.
- **Worked exercise** — a small task in the real tool (a SOQL query to
  write, a code snippet to review, a config to sketch) with a model
  answer, again collapsed.

When the user answers drills in chat, grade against the mechanism,
name the exact misconception when wrong, and log the weak spots in the
tracker — they become the next session's warm-up.

### 4. Progress tracking

One tracker per track: `~/workspace/learning/<track>/TRACKER.md`.

| Course | Section | Notes | Drills | Weak spots | Next |
|---|---|---|---|---|---|

Update it at the end of every study session, and read it at the start
of the next one — resuming means "last session you finished X, weak on
Y, next is Z", stated before any new work. Streaks and percentages are
the user's business inside LinkedIn Learning; this tracker records
*understanding*, not playback.

## Boundaries

- No LinkedIn login, enrollment, or playback automation — the user's
  browser, the user's account actions.
- No credential requests, ever; no video downloads; work only from
  material the user can legitimately share in-session.
- Don't invent course contents: if a syllabus or transcript isn't
  available, say the notes for that section are blocked on it and offer
  the shortlist-phase material instead.
- Certifications and graded assessments stay the user's — drills are
  practice, never a substitute submission.
