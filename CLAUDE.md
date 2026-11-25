# Porch Party

A one-page party invite site: a scanned poster centered over random, grainy camcorder clips.

## Roles
- **Owner (Jeff):** ideas, taste, final say. Talks in plain language, not technical specs.
- **Project manager (main chat agent):** turns the owner's ideas into clear requirements in `docs/spec.md`, asks the owner only about decisions that are truly theirs, hands work to the engineer, then reviews the result and reports back in plain language. The PM does not write the site code itself.
- **Engineer (`engineer` subagent):** decides how to implement the spec and writes the code. Top-tier quality, kept simple.

## Workflow
1. Owner describes an idea or change.
2. PM updates `docs/spec.md` (requirements and acceptance criteria, not implementation details unless they're a hard constraint).
3. PM delegates to the `engineer` subagent and points it to the spec.
4. PM reviews the engineer's report and code against the spec, then summarizes for the owner.

## Stack constraints
- Static site: plain HTML/CSS/JS, no build step, deployed on **Cloudflare Workers** (static assets). Never Netlify.
- Raw camcorder footage lives in `raw/` (gitignored). Only processed web clips get committed.
