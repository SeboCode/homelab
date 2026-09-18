---
name: refine-agent-definitions
description: Improve the skill and agent definitions after a run the human judged inadequate. Routes the failure to its root cause, has each implicated agent propose changes to its own definition, and applies them only with human approval. Human-initiated only - never run this on your own judgement.
argument-hint: <what went wrong>
---

# Refine the agent and skill definitions

**Only the human starts this.** Never launch it because you thought a run went badly, and
never fold it into the end of another task. An agent that rewrites its own instructions
unprompted is a drift machine.

Scope: the definitions themselves. Not the service that was just built — fix that
separately, through the normal loop.

## Step 1 — Gather the evidence

Reflection from memory produces plausible fiction. Collect the artifacts first:

- **What the human said was wrong.** This is the ground truth. If it is vague, ask what
  specifically was unacceptable before going further.
- The brief, the chart, and the verifier's findings from the run.
- Each agent's report from the run, as it was returned.
- The current text of the skills and agent files involved.

Subagents do not remember their runs. Anything not in these artifacts is gone, so work
from them rather than reconstructing.

## Step 2 — Find the root cause, not the symptom

Ask where the failure was first introduced, then where it should have been caught:

| The failure was…                         | Change                                                  |
| ---------------------------------------- | ------------------------------------------------------- |
| a fact that was wrong or missing         | the **researcher** skill or agent                       |
| a decision the brief left implicit       | the **researcher** skill or agent                       |
| the chart not matching an adequate brief | the **implementer** skill or agent                      |
| a repository convention nobody encoded   | `AGENTS.md`, or the conventions the researcher extracts |
| something the human had to notice        | the **verifier** skill — always                         |

That last row is not optional. **If the human found it, the verifier missed it**, so the
verifier checklist is implicated in every single run of this skill, in addition to
whatever else is. A defect that reaches a human is two failures, not one.

State the root cause in one sentence before proposing anything. If you cannot, you do not
understand the failure yet.

## Step 3 — Have each implicated agent propose its own change

Dispatch each one in **reflection mode**, passing:

- the human's complaint, verbatim
- that agent's own report from the run
- the relevant artifacts (brief, chart, findings)
- the current text of its skill and agent file

Each returns **proposed replacement text** with exact old and new strings — not a
description of a change, and not a rewritten file. Do not dispatch an agent that was not
implicated; it will invent a lesson to justify the dispatch.

Agents propose; you apply after approval. That keeps one gate and stops three agents
editing overlapping files at once.

### What a dispatched agent is being asked for

An agent in reflection mode has these constraints, and they are the same for every agent:

- Address the root cause of the complaint, not the symptom.
- Keep it general. A fact about one service belongs in a brief, never in a definition.
- Prefer making an existing rule more precise over adding another one.
- **Never propose weakening a constraint**: secret handling, the `latest` prohibition,
  deny-by-default networking, production read-only, the human confirmation gate, or the
  separation between research, implementation and verification. Friction with one of
  those is the constraint working — say so and propose nothing.
- At most two changes per agent. Having none worth making is a valid and common answer.

**Never edit your own definition directly.** You propose; the human approves and the
orchestrating session applies.

## Step 4 — What makes a change worth making

Accept a proposal only if it passes all of these:

- **It is specific.** "Be more careful with ports" changes nothing. "Record the port as a
  number with its source URL in the Decisions table" changes behaviour.
- **It addresses the root cause**, not the symptom.
- **It would have prevented this failure**, and you can say how.
- **It generalises.** A fact about one service belongs in that service's brief or in the
  conventions, never in a skill. Encoding a one-off as a permanent rule is the most
  common way these files rot.
- **It sharpens an existing rule rather than adding a new one**, where possible. Three
  vague rules are worse than one precise rule.
- **It does not weaken a constraint.** Never relax secret handling, the `latest`
  prohibition, deny-by-default networking, production read-only, the human gate, or the
  separation between research, implementation and verification — however much friction
  an agent reports from them. Friction with a safety rule is the rule working.

Reject anything else and say why. A rejected proposal is a normal outcome.

**Cap it at two changes per run.** A skill that grows every time something goes wrong
becomes long enough that nothing in it is read carefully, at which point every rule is
weaker.

## Step 5 — Present, approve, apply

Show the human a diff per file: the exact before and after, the failure it addresses, and
how it would have prevented it. Nothing is written until they approve. They may accept
some and reject others.
