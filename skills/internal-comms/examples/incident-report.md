## Instructions

You are writing an incident report for Qompass AI infrastructure or tooling. Matt runs
security-sensitive systems (agent fleets, MCP servers, public repos, his workstation).
Incident reports here are blameless, precise, and evidence-first — written like an
intel report: what is confirmed, what is suspected, what is unknown.

Write it as soon as the incident is contained; update it as the investigation closes
gaps. Never let the report outrun the evidence.

## Sources

- **Logs and tool output**: the primary source. Quote or cite exact lines, timestamps,
  exit codes.
- **Repo state**: the commits, configs, or deploys in play at the time (`git log`,
  SHAs).
- **Timeline reconstruction**: calendar events, message timestamps, gate runs —
  anything with a clock on it.
- **Matt**: he directed the response; confirm the response actions with him.

## Formatting

# Incident: <short title> (<date>)

## Summary
[2–4 sentences: what happened, what was affected, current status — contained /
mitigated / resolved.]

## Impact
[Who or what was affected, for how long. Scope it with evidence: "X was unreachable
from <time> to <time>" — not "users may have experienced issues."]

## Timeline
[Chronological, timestamped. Each entry: time, event, source.]
- <HH:MM TZ> — [event] ([source: log line, message, gate run])

## Root cause
[The verified cause. If the cause is not yet confirmed, label each candidate
explicitly as HYPOTHESIS and say what would confirm or rule it out. Never present a
hypothesis as a finding.]

## Response
[What was done to contain/mitigate, in order, with who did it (Matt, which agent) and
when.]

## Follow-ups
- [ ] [action] — owner: [Matt / agent] — due: [date or "next session"]

## Lessons
[1–3 sentences: what changes so this class of incident doesn't recur. Concrete, not
homilies.]

Rules: confirmed vs. suspected is marked everywhere it matters. No blame language —
describe mechanisms, not people. Every timestamp carries its timezone. If impact is
unknown, say "impact unknown; investigated <how>" rather than guessing.
