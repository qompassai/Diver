---
name: agentscript-dev
description: >
  Author and test Salesforce Agentforce agents written in AgentScript
  (.agent files) from the terminal and Matt's Neovim: structure an agent as
  topics, actions, and variables; keep the script in an SFDX project's
  aiAuthoringBundles; preview conversations with `sf agent preview`;
  deploy and iterate against a Trailhead Playground or Agentforce dev org.
  Use when the user asks to "write an agent", "edit this .agent file",
  "add a topic/action to the agent", "test the agent", or is working
  Agentforce/Agentblazer modules that involve AgentScript. Companion to
  sf-org-workflows (org/deploy plumbing) and apex-dev (Apex actions).
license: Apache-2.0
compatibility: >
  Requires the `sf` CLI with the Agentforce DX agent plugin (verified on
  primo: the `sf agent` topic responds and `sf agent preview --help`
  works, @salesforce/cli 2.152.14). Requires an Agentforce-enabled org —
  a Trailhead Playground with Agentforce, or the agentforce-de org.
  A plain DE org without agents cannot preview or run agents; that was
  the recorded blocker on the Prompt Builder / Models API modules.
metadata:
  app: salesforce-agentscript
  filetype: .agent (aiAuthoringBundles)
allowed-tools: Read Edit Bash
---

# AgentScript development

AgentScript is Salesforce's text language for defining an Agentforce
agent: one `.agent` file declares the agent's instructions, its topics
(conversation domains), the actions each topic may invoke (Apex classes,
flows, prompt templates), and the variables that carry state between
turns. The file lives in source control and deploys like other metadata —
which is what makes it an editor-and-CLI workflow instead of a clicking
workflow.

Honesty note: on primo, the `sf agent` command surface is verified
present; org-side preview/run was *not* exercised in the prior program
because the available DE org had no agent provisioned (see Edge cases).
Commands below follow Salesforce's Agentforce DX documentation for this
CLI generation — re-check `sf agent --help` on the machine before relying
on a flag.

## File layout

```
force-app/main/default/aiAuthoringBundles/<AgentName>/
├── <AgentName>.agent            # the AgentScript source
└── <AgentName>.agent-meta.xml   # bundle metadata
```

An AgentScript file is a sequence of blocks:

- `system:` — global instructions and messages (tone, guardrails,
  escalation wording). Applies to every topic.
- `config:` — developer name, description, default agent user, and
  other agent-level settings.
- `variables:` — typed state (e.g. `verified_customer: boolean`),
  settable by actions or by the conversation.
- `topic <name>:` — one per job the agent does. Each topic has a
  description (the router reads it to pick the topic — write it like
  you'd brief a human on when this topic applies), `reasoning`
  instructions, and `actions`.
- `action <name>:` — inside a topic; binds a target (Apex class, flow,
  or prompt template) with declared inputs/outputs. Outputs can set
  variables and feed the reasoning step.

Authoring rule of thumb: the topic *description* and the *reasoning*
text do the routing work. Most "the agent picks the wrong topic"
bugs are description bugs, not model bugs.

## The loop

1. **Edit** the `.agent` file in Neovim. Keep one topic per file
   section, actions named for what they do (`get_order_status`, not
   `action1`).
2. **Deploy the bundle** to the playground (see `sf-org-workflows`):
   `sf project deploy start -o trailheadPlayground -m AiAuthoringBundle:<AgentName>`
   (or deploy the source path). A compile error here is a script or
   binding error — read it literally; it names the block.
3. **Preview the conversation:**
   `sf agent preview -o trailheadPlayground --agent-api-name <AgentName>`
   Drive it with the utterances the module or test plan cares about —
   the exact phrases a user would type, including sloppy ones.
4. **Test systematically** when the org supports agent tests: author
   utterance/expected-topic/expected-action cases and run them through
   the agent testing commands (`sf agent test ...` — check `--help` for
   the current subcommands) instead of judging from one good chat.
5. **Actions in Apex** are ordinary Apex: write and test them with the
   `apex-dev` loop, then bind them in the script. Keep actions small,
   bulk-safe, and explicit about their outputs — the script can only
   reason over what an action declares.
6. **Record and park** (Trailhead context): update the module status
   file with what was deployed/previewed; agent *activation* and any
   graded steps remain Matt's, as with every module.

## Judgment calls worth teaching

- **Deterministic beats clever.** If a step must always happen (verify
  identity before showing account data), encode it in topic flow and
  variables — not as a polite request in the instructions text.
- **Descriptions are routing.** Two topics whose descriptions overlap
  will steal each other's conversations. Differentiate by user intent,
  not by internal implementation.
- **Variables are the contract** between actions and reasoning. Name
  them for the business fact, type them, and never let an action's
  undeclared side effect become load-bearing.

## Edge cases

- **No agent in the org:** preview/run fail or find nothing. This is an
  org-provisioning state, not a script bug — it blocked the Prompt
  Builder and Models API units in the Agentblazer Legend run. The fix
  (provision an agent, or spin up an Agentforce Playground) is Matt's
  decision; record it in the status file and move on.
- **Deploy succeeds, behavior stale:** confirm the deployed version is
  the active one in the org; preview targets the org's agent, not the
  file on disk.
- **Never develop agents against map-dev** (sealed production org) —
  playgrounds and the Agentforce dev org only.
- **Credentials and connected apps** for agent authentication are
  separate, sensitive setup; the "Deploying Agent Authentication"
  module is parked on its own org decision for this reason.
