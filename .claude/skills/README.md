# AID Skills for Claude Code

10 skills in AgentSkills format. Each `SKILL.md` contains YAML frontmatter with `name`, `description`, `allowed-tools`, `context`, and `agent` fields.

## Skills

| Skill | Phase | Agent | Description |
|-------|-------|-------|-------------|
| `aid-init` | 0. Init | Orchestrator | Initialize project — greenfield/brownfield, scaffold KB, collect metadata |
| `aid-discover` | 1. Discover | Researcher | Brownfield project discovery with quality gate (GENERATE → REVIEW → Q&A → FIX → APPROVAL → DONE) |
| `aid-interview` | 2. Interview | Interviewer | Adaptive requirements gathering → REQUIREMENTS.md |
| `aid-specify` | 3. Specify | Architect | Requirements → SPEC.md grounded in KB |
| `aid-plan` | 4. Plan | Architect | SPEC.md → high-level roadmap (PLAN.md) |
| `aid-detail` | 5. Detail | Architect | PLAN.md → user stories, tasks, execution waves |
| `aid-execute` | 6. Implement | Developer | TASK → code with build verification |
| `aid-execute` | 8. Test | Critic | Staging validation — E2E, integration, manual |
| `aid-deploy` | 9. Deploy | Operator | Final verification, PR, KB updates |
| `aid-monitor` | 8. Monitor | Orchestrator | Observe, classify, route production findings |

## Usage

Skills are loaded automatically when matched by description. The `context: fork` field means each skill runs in an isolated subagent context.

See the repo's [`skills/`](../../skills/README.md) directory for human-readable documentation with rationale and examples.
