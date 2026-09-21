# BRIEFING — 2026-09-21T19:10:28Z

## Mission
Exhaustively test, resolve, and automate patch compatibility across the entire dwl-flake patch matrix for both stable and main channels, and fix upstream nixpkgs module comparison failures.

## 🔒 My Identity
- Archetype: teamwork_preview_orchestrator
- Roles: orchestrator, user_liaison, human_reporter, successor
- Working directory: /home/rebiz/opt/dwl-flake/.agents/teamwork_preview_orchestrator_1
- Original parent: parent
- Original parent conversation ID: 8fd46a8c-6177-4c48-816b-4cfa91c1ca6f

## 🔒 My Workflow
- **Pattern**: Project
- **Scope document**: /home/rebiz/opt/dwl-flake/PROJECT.md
1. **Decompose**: Decompose full dwl-flake patch matrix, conflict engine, and upstream parity into milestones.
2. **Dispatch & Execute**:
   - **Direct (iteration loop)**: Explorer (3) -> Worker (1) -> Reviewer (2) -> Challenger (2) -> Auditor (1) -> Gate
3. **On failure** (in this order):
   - Retry: nudge stuck agent or re-send task
   - Replace: spawn fresh agent with partial progress
   - Skip: proceed without (only if non-critical)
   - Redistribute: split stuck agent's remaining work
   - Redesign: re-partition decomposition
   - Escalate: report to parent (sub-orchestrators only, last resort)
4. **Succession**: At 16 spawns, write handoff.md, spawn successor
- **Work items**:
  1. Survey and Scope Analysis [in-progress]
  2. Test Infrastructure & E2E Testing Track [pending]
  3. Upstream Parity & nixpkgs module comparison [pending]
  4. Conflict Resolution Engine (nix/apply-patches.sh) [pending]
  5. Individual Patch Matrix Compatibility [pending]
  6. Multi-patch Combination Suites [pending]
  7. Final Verification & Flake Checks [pending]
- **Current phase**: 0 (Survey)
- **Current focus**: Survey and Scope Analysis

## 🔒 Key Constraints
- DISPATCH-ONLY orchestrator: NEVER write source code directly, NEVER run build/test commands directly.
- NEVER investigate or explore the problem at the code level — dispatch Explorers for technical investigation.
- All implementations must be genuine; no cheating, dummy implementations, or hardcoded tests.
- Audit is a binary veto; any integrity violation unconditionally fails milestone.
- Never reuse a subagent after it has delivered its handoff — always spawn fresh.
- Successor threshold is 16 spawns.

## Current Parent
- Conversation ID: 8fd46a8c-6177-4c48-816b-4cfa91c1ca6f
- Updated: not yet

## Key Decisions Made
- Initialized Project Orchestrator state. Initiating Step 0 Survey with 3 parallel Explorers / Spec Miners.

## Team Roster
| Agent | Type | Work Item | Status | Conv ID |
|-------|------|-----------|--------|---------|
| survey_upstream_1 | teamwork_preview_spec_miner | Upstream Parity & Flake Check Survey | in-progress | e12a7608-b1a0-4284-a3cc-60f5391cd42c |
| survey_conflict_engine_1 | teamwork_preview_explorer | Conflict Engine & Patch Application Survey | in-progress | afd6ad3a-d454-4d82-9fb2-1b96ee59e5d4 |
| survey_patch_matrix_1 | teamwork_preview_explorer | Patch Matrix & Combinations Survey | in-progress | 53a45342-e149-4594-8b14-0969b6a192e0 |

## Succession Status
- Succession required: no
- Spawn count: 3 / 16
- Pending subagents: e12a7608-b1a0-4284-a3cc-60f5391cd42c, afd6ad3a-d454-4d82-9fb2-1b96ee59e5d4, 53a45342-e149-4594-8b14-0969b6a192e0
- Predecessor: none
- Successor: not yet spawned

## Active Timers
- Heartbeat cron: 2d83ba3c-df29-48a1-aacf-301151fe1b22/task-16
- Safety timer: none
- On succession: kill all timers before spawning successor
- On context truncation: run `manage_task(Action="list")` — re-create if missing

## Artifact Index
- /home/rebiz/opt/dwl-flake/ORIGINAL_REQUEST.md — Original request
- /home/rebiz/opt/dwl-flake/.agents/teamwork_preview_orchestrator_1/DISPATCH.md — Dispatch history
- /home/rebiz/opt/dwl-flake/.agents/teamwork_preview_orchestrator_1/BRIEFING.md — Persistent working memory
- /home/rebiz/opt/dwl-flake/.agents/teamwork_preview_orchestrator_1/progress.md — Progress and liveness signal
