# capscan

capscan is a companion to Dependabot that reviews dependency updates for new capabilities a repository could adopt, such as a built-in that can replace a third-party package.
Dependabot answers what changed and whether it is safe.
capscan answers what the change unlocks for this codebase, grounded in specific files and lines.

It accompanies the blog post [Your Dependencies Shipped Features Too](https://stevehenderson.github.io/Dependencies-Shipped-Features/).
[stevehenderson/capscan-demo](https://github.com/stevehenderson/capscan-demo) has it installed on two small services, with the reports it produced.

capscan runs two ways from the same rules and scripts:

- **In GitHub Actions**, as two [GitHub Agentic Workflows](https://github.github.com/gh-aw/): one comments on each Dependabot pull request, and one opens a weekly sweep issue.
- **On a workstation**, as an [Agent Skill](https://agentskills.io) that Claude Code, Copilot, or another agent that reads skills runs on request.

## What is in this repository

| Path | Purpose |
|---|---|
| `plugin/skills/capscan/SKILL.md` | The skill: how an agent runs a review on a workstation |
| `plugin/skills/capscan/RULES.md` | The agent rules that define a capability review, shared by the skill and the workflows |
| `plugin/skills/capscan/scripts/gather-facts.sh` | Gathers the facts a review starts from: a dependency inventory with the lines that use each dependency, govulncheck, the GODEBUG diff, version declarations, and npm outdated and audit |
| `plugin/skills/capscan/scripts/verify-report.sh` | Checks every cited `path:line` and link before a report is published |
| `workflows/capscan.md` | The agentic workflow that reviews each Dependabot pull request and comments with the report |
| `workflows/capscan-sweep.md` | The agentic workflow that runs weekly and opens an issue covering version gates and drift that no Dependabot PR surfaces |
| `aw.yml` | The gh-aw package manifest that installs the workflows, rules, and scripts |
| `plugin/`, `.claude-plugin/` | The Claude Code plugin that holds the skill, and the marketplace manifest that installs it |
| `examples/claude-settings.json` | Claude Code permissions for running the skill |
| `examples/claude-code-action/` | The same two workflows built directly on `anthropics/claude-code-action`, for comparison |

## Install the workflows

1. Install the CLI with `gh extension install github/gh-aw`.
2. From the repository to review, install the package:

   ```console
   gh aw add stevehenderson/capscan@v1.0.0
   ```

   This writes the two workflows and their compiled lock files to `.github/workflows/`, and the rules and scripts to `.github/aw/capscan/`.
3. Adjust `network.allowed` and the host list passed to `verify-report.sh` for the ecosystems in use.
   The scripts cover Go modules and npm projects.
4. Add a token for the engine.
   On a personal repository, the Copilot engine needs a fine-grained personal access token with the Copilot Requests permission, stored as `COPILOT_GITHUB_TOKEN`.
   Organizations with Copilot billing can use the built-in token with `copilot-requests: write` instead.
   Workflows triggered by Dependabot can read only Dependabot secrets, so the token goes in both stores:

   ```console
   gh secret set COPILOT_GITHUB_TOKEN --app dependabot
   gh secret set COPILOT_GITHUB_TOKEN --app actions
   ```

5. Commit everything `gh aw add` wrote, including the lock files and `.github/aw/`.
6. Exclude the lock files from Dependabot's `github-actions` updates, since gh-aw generates them:

   ```yaml
   exclude-paths:
     - ".github/workflows/*.lock.yml"
   ```

To use Claude, Codex, or Gemini, change `engine:` and set that engine's secret.
`gh aw update` pulls newer releases of the package and merges them with local changes.

### How the workflows are built

- The agent job is read-only, and its network egress goes through a firewall that allows only the hosts listed under `network:`.
- The agent's only write path is a declared safe output: one `add-comment` on the triggering pull request, or one `create-issue` for the sweep.
  A separate job applies it after a threat-detection pass.
- The shell available to the agent is limited to the commands listed under `tools.bash`.
- Fixed steps gather facts before the agent starts and pass them to the agent as files.
- Every report must pass `verify-report.sh` in the safe-outputs job before it is published.
  The script confirms that cited lines exist and that links use allowed hosts; it does not confirm that the claims in the report are correct, so a person still reviews each finding.
- Actions and containers in the compiled lock files are pinned to commit SHAs and digests.

## Install the skill

In Claude Code, add this repository as a plugin marketplace and install the plugin:

```console
claude plugin marketplace add stevehenderson/capscan
claude plugin install capscan@capscan
```

For other agents, or to pin the skill in one repository, copy `plugin/skills/capscan/` into the directory the agent reads skills from, such as `.claude/skills/`, `.github/skills/`, or `.agents/skills/`.

Then, from a clone of the repository to review, ask for a review.
Plugin skills are namespaced by plugin, so the installed plugin's command is `/capscan:capscan`, and a copied skill's command is `/capscan`:

```console
claude "/capscan:capscan review the open Dependabot pull requests"
claude "/capscan:capscan sweep"
claude "what would moving to Go 1.25 give the inventory service?"
```

The skill runs `gather-facts.sh`, reads the rules, researches each candidate, and writes verified reports to `capscan-reports/`.
It does not post, commit, or push anything.
Add `capscan-input/` and `capscan-reports/` to `.gitignore`.

### Running the skill safely

On a workstation the agent runs with the person's own credentials and shell.
`examples/claude-settings.json` pre-approves the skill's read-only commands and denies pushes, merges, comments, and package installs.
Copy it to `.claude/settings.json` in the repository to review, or merge it into existing settings.
Claude Code applies a project's settings only after the repository has been trusted interactively.

A deny list guards against mistakes, and it is weaker than credentials that cannot write.
For code that matters, also set `GH_TOKEN` to a fine-grained token with read-only access, and run the agent in a dev container or with Claude Code's sandbox enabled.

## License

MIT
