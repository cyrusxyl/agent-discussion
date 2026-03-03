---
name: agent-discussion
description: >
  Multi-agent discussion coordination skill. Use this immediately when the user invokes
  /agent-discussion, "start a debate", "join the discussion", "let's debate", or wants
  multiple AI agents (Claude Code, Antigravity, Copilot, Gemini CLI, etc.) to coordinate
  on a topic through a shared file. Trigger without waiting for more context.
---

# Agent Discussion

You coordinate a multi-agent discussion by reading and appending to a shared file. Your job is to run the entire discussion loop autonomously — setup briefly with the user, then disappear into the loop and don't come back until the discussion reaches a conclusion. The user should be able to walk away after setup.

## Setup

Collect three pieces of information. If provided inline (e.g. `/agent-discussion agent:claude topic:"REST vs GraphQL" file:./discussion.md`), use them directly and skip the questions.

1. **Your name** — one short word, lowercase (default: your platform, e.g. `claude`, `antigravity`, `copilot`)
2. **File path** — where the shared discussion lives (default: `./discussion.md`)
3. **Topic** — only needed if you are starting a new discussion (file doesn't exist)

### Starting vs. Joining

Check whether the discussion file already exists.

**File doesn't exist** → You are the first agent. Create the file using the format below, take your first turn, then enter the loop immediately — no need to report back to the user at this point.

**File exists** → You are joining. Read the file to learn the topic (a single brief confirmation to the user is fine: "Joining discussion on X"), then enter the loop immediately.

### Creating the File

```
# Discussion: <topic>
<!-- status:active -->
Started: <datetime>

[TURN: <your-name>]
```

Then take your first turn right away.

## The Loop

After your first turn (and immediately after joining), enter this loop and stay in it. Do not pause between rounds to report to the user — run silently until the discussion reaches a conclusion.

### Waiting for your turn

Use the bundled watcher script to block efficiently on file changes rather than polling on a timer:

```bash
bash <skill-dir>/scripts/watch_turn.sh <file> <your-name>
# exit 0 → it's your turn
# exit 1 → discussion over (AGREED or DEADLOCKED)
```

The script uses `inotifywait` (Linux) for event-driven watching with zero CPU — it only wakes up when the file actually changes. If `inotifywait` isn't available it falls back to checking the file's modification time every 3 seconds. Either way it blocks silently until something happens, so you don't need to manage sleep timers yourself.

`<skill-dir>` is the directory containing this SKILL.md file. If you don't know the path, locate it with: `find ~ -name "watch_turn.sh" -path "*/agent-discussion/scripts/*" 2>/dev/null | head -1`

### The full loop

```
1. Run watch_turn.sh — it blocks until the file changes
2. Exit 1 (AGREED/DEADLOCKED) → report outcome to the user, stop
3. Exit 0 (your turn)         → take your turn (see below), then go to step 1
4. If round count > 12        → write [DEADLOCKED], report to user, stop
```

**Waiting for a partner:** If `[TURN: NEXT]` is still the last marker after several watcher cycles, let the user know the discussion is waiting for another agent to join, then keep the loop running — don't quit. The other agent will write to the file when it joins, and the watcher will wake you up.

## Taking Your Turn

1. Read the **full file** to understand the conversation history.
2. **Concurrent-write guard** — immediately before appending, re-read the last 10 lines and confirm `[TURN: you]` is still the final turn marker. If it has changed, another agent wrote while you were thinking. Skip this turn and return to polling.
3. **Is this your first turn?** Search the file for `**<your-name> (Intro):**`.
   - **Not found** → write your Intro (see below) before taking any position
   - **Found** → write your next Round (determine N from the highest `Round N` in the file; yours is N+1)
4. Append to the end of the file using the appropriate format below.
5. Go back to step 1 of the loop (run watch_turn.sh again) — do not surface to the user.

### Your Intro (first turn only)

The Intro grounds both agents in shared facts — it is the foundation the whole discussion builds on. A generic intro ("both sides have tradeoffs") leads to a generic discussion. A research-backed intro surfaces concrete evidence both agents can actually argue over.

**Research sprint (do this before writing):**

Before writing, spend a few minutes actively gathering evidence. The right sources depend on the topic:

- **Codebase topics** (architecture decisions, library choices, patterns in use): explore the repo — grep for relevant files, configs, and existing implementations. What has the project already decided? What does the code reveal about current constraints?
- **Technology or concept topics** (language comparisons, frameworks, protocols): look up benchmarks, official documentation, adoption data, known failure modes. Prefer specific findings over general summaries.
- **Mixed topics**: do both. The codebase tells you the *current state*; external sources tell you the *tradeoffs*.

Then **select your best 3–4 findings** — with only 100–150 words in the Intro, pick the facts that are most concrete and most likely to be contested: a specific statistic, a named limitation, a real adoption pattern.

A well-researched intro cites specific things — version numbers, benchmark results, documented gotchas — rather than restating common knowledge. That specificity is what makes the subsequent debate worthwhile.

After your research sprint, write your intro:

```
**<your-name> (Intro):** <100–150 words of neutral analysis — key facts, tradeoffs, and
considerations on both sides. Ground it in what you found. No advocacy. No "I think".>

[TURN: <other-agent or NEXT>]
```

### Subsequent Rounds

After both Intros are written, the numbered discussion begins:

```
**<your-name> (Round <N>):** <your argument — 150 words max>

[TURN: <other-agent>]
```

### Rules

- **Append only.** Never modify or delete existing content.
- **Engage specifically.** Reference the other agent's exact points; don't repeat your own.
- **If circling** (5+ rounds, same arguments) — propose a synthesis or narrow the scope.

## Reaching Agreement

When you genuinely agree with the other agent's position (not before Round 3):

```
**<your-name> (Round <N>):** I agree with <other-name>. <One sentence summarising what we settled on.>

[AGREED: <summary>]
```

Then report back to the user: show them the agreed summary and the final discussion file path.

## Deadlock

If you reach Round 12 without agreement, or the conversation has clearly stalled:

```
**<your-name> (Round <N>):** Unable to reach agreement. Key unresolved points:
- <point 1>
- <point 2>

[DEADLOCKED]
```

Then report back to the user: summarise the unresolved points and ask if they want to intervene or let it go.

## Finding the Other Agent's Name

Read `[TURN: …]` markers and `**name (Round N):**` or `**name (Intro):**` headers already in the file. Use this name for `[TURN: …]` at the end of your message.

If you are the first agent and don't yet know who will join, write `[TURN: NEXT]`. Any joining agent treats `[TURN: NEXT]` as their cue to go.

## Being a Good Participant

- **Seek the best outcome, not a win.** If the other agent is right, say so.
- **Let your Intro inform your position.** The facts you stated neutrally should shape — and sometimes constrain — your argument.
- **Propose concrete things.** Vague agreement is useless — name the specific approach, tradeoff, or decision.
- **Synthesise when stuck.** "What if we combine X from your position and Y from mine?" is more productive than repeating yourself.
- **Stay on topic.** Don't discuss the process; discuss the subject.
