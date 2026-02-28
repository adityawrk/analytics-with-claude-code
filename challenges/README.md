# Analytics Challenges

Four progressively harder challenges to sharpen your Claude Code analytics
skills. Each one uses the demo dataset and targets specific slash commands.

Work through them in order, or jump straight to the difficulty that matches
your experience level.

---

## Challenge Index

| #  | Name              | Difficulty   | Time   | Skills Used                          |
|----|-------------------|--------------|--------|--------------------------------------|
| 01 | Data Detective    | Beginner     | 10 min | `/eda`, `/data-quality`              |
| 02 | Query Surgeon     | Intermediate | 15 min | `/sql-optimizer`, `/explain-sql`     |
| 03 | Metric Mystery    | Advanced     | 20 min | `/metric-reconciler`                 |
| 04 | A/B Test Trap     | Expert       | 30 min | `/ab-test`                           |

---

## How to Use

1. **Set up the demo database first** (if you haven't already):

   ```bash
   cd demo
   pip install duckdb
   python setup_demo_data.py
   ```

2. **Open a challenge** (run Claude Code from the repo root so it picks up CLAUDE.md and skills):

   ```bash
   claude "Open challenges/01-data-detective/CHALLENGE.md and walk me through it"
   ```

3. **Read the CHALLENGE.md** — each one gives you a scenario, a dataset, and a
   goal. Use the suggested skills to solve it.

4. **No peeking at solutions.** The point is to learn the workflow, not to get
   the "right answer" as fast as possible. Let Claude guide you.

---

## Difficulty Guide

**Beginner** — You're new to Claude Code or analytics tooling. These challenges
teach you the core slash commands and how to interpret their output.

**Intermediate** — You write SQL regularly and want to learn how Claude can
accelerate your workflow. These challenges involve real optimization problems.

**Advanced** — You've hit the classic "why don't the numbers match?" problem at
work. These challenges teach you how to use Claude to debug metric discrepancies.

**Expert** — You design experiments and know that statistical significance
isn't the whole story. These challenges test whether you (and Claude) can spot
the traps that fool most analysts.

---

## Tips

- Use `/eda` liberally — it's the fastest way to understand any dataset.
- When a challenge includes inline data (CSV blocks), paste it into a file
  before asking Claude to analyze it.
- If you get stuck, ask Claude: "What should I try next?" The skills are
  designed to chain together.
- After completing a challenge, try `/explain-sql` on the final query to
  deepen your understanding.
