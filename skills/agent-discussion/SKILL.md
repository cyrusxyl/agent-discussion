---
name: agent-discussion
description: >
  Multi-agent discussion coordination skill. Use this immediately when the user invokes
  /agent-discussion, "start a debate", "join the discussion", "let's debate", or wants
  multiple AI agents (Claude Code, Antigravity, Copilot, Gemini CLI, etc.) to coordinate
  on a topic through a shared file. Trigger without waiting for more context.
---

# Agent Discussion

You coordinate a multi-agent discussion by reading and appending to a shared file. Run this process **autonomously** — the user should not need to intervene after setup.

## Setup

Collect three pieces of information. If provided inline (e.g. `/agent-discussion agent:claude topic:"REST vs GraphQL" file:./discussion.md`), use them directly and skip the questions.

1. **Your name** — one short word, lowercase (default: your platform, e.g. `claude`, `antigravity`, `copilot`)
2. **File path** — where the shared discussion lives (default: `./discussion.md`)
3. **Topic** — only needed if you are starting a new discussion (file doesn't exist)

### Starting vs. Joining

Check whether the discussion file already exists.

**File doesn't exist** → You are the first agent. Ask for the topic, create the file using the format below, and take your first turn immediately.

**File exists** → You are joining. Read the file, tell the user the topic, and enter the loop.

### Creating the File

```
# Discussion: <topic>
<!-- status:active -->
Started: <datetime>

[TURN: <your-name>]
```

Then take your first turn right away.

## The Loop

Repeat until the discussion reaches a terminal state:

```
1. Read only the last ~25 lines of the file (fast check)
2. Find the last [TURN:…], [AGREED:…], or [DEADLOCKED] line
3. [AGREED] or [DEADLOCKED]  → print the outcome, stop
4. [TURN: you]               → take your turn (see below)
5. [TURN: other] or [TURN: NEXT] → wait ~10 seconds, go to step 1
6. If round count > 12       → write [DEADLOCKED] and stop
```

**Read only the last ~25 lines during polling.** Reading the full file every cycle wastes tokens over a long discussion. Reserve a full read for when it's actually your turn.

> **Tip (bash):** `tail -n 25 ./discussion.md` is an efficient way to poll. Other platforms can read the file and focus on the final section.

**Waiting for a partner:** If you see `[TURN: NEXT]` unchanged across three consecutive polls, let the user know the discussion is waiting for another agent to join. Continue waiting — don't quit.

## Taking Your Turn

1. Read the **full file** to understand the conversation history.
2. **Concurrent-write guard** — immediately before appending, re-read the last 10 lines and confirm `[TURN: you]` is still the final turn marker. If it has changed, another agent wrote while you were thinking. Skip this turn and return to polling.
3. **Is this your first turn?** Search the file for `**<your-name> (Intro):**`.
   - **Not found** → write your Intro (see below) before taking any position
   - **Found** → write your next Round (determine N from the highest `Round N` in the file; yours is N+1)
4. Append to the end of the file using the appropriate format below.

### Your Intro (first turn only)

Before staking a position, write an unbiased overview of the topic:

```
**<your-name> (Intro):** <100–150 words of neutral analysis — key facts, tradeoffs, and
considerations on both sides. No advocacy. No "I think". Just what's true about the topic.>

[TURN: <other-agent or NEXT>]
```

The Intro grounds both agents in shared facts. It prevents entrenched advocacy early and makes the eventual agreement easier to reach because both sides acknowledge the same tradeoffs. Think of it as writing the Wikipedia lead paragraph for the topic.

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

## Deadlock

If you reach Round 12 without agreement, or the conversation has clearly stalled:

```
**<your-name> (Round <N>):** Unable to reach agreement. Key unresolved points:
- <point 1>
- <point 2>

[DEADLOCKED]
```

## Finding the Other Agent's Name

Read `[TURN: …]` markers and `**name (Round N):**` or `**name (Intro):**` headers already in the file. Use this name for `[TURN: …]` at the end of your message.

If you are the first agent and don't yet know who will join, write `[TURN: NEXT]`. Any joining agent treats `[TURN: NEXT]` as their cue to go.

## Being a Good Participant

- **Seek the best outcome, not a win.** If the other agent is right, say so.
- **Let your Intro inform your position.** The facts you stated neutrally should shape — and sometimes constrain — your argument.
- **Propose concrete things.** Vague agreement is useless — name the specific approach, tradeoff, or decision.
- **Synthesise when stuck.** "What if we combine X from your position and Y from mine?" is more productive than repeating yourself.
- **Stay on topic.** Don't discuss the process; discuss the subject.
