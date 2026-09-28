# Salesforce auth setup for the agent-task workstream

The agent tasks cannot authenticate for you: Salesforce login needs a
browser and your credentials. Do this once per machine, then the
async tasks can run.

## 1. Check what the CLI already knows

```sh
sf org list --json
```

This lists every org the CLI holds credentials for. Empty list means
nothing is authorized yet.

## 2. Log in (interactive -- run this yourself)

```sh
sf org login web --alias my-playground --set-default
```

- `--alias` names the org so later commands can use
  `--target-org my-playground`.
- `--set-default` makes it the default, so task steps that omit
  `--target-org` still work.
- A browser window opens; complete the Salesforce login there.

Both flags are verified in the Salesforce CLI Command Reference
(see `FLAGS.md`).

## 3. Verify from inside Neovim

```vim
:SfTasksDispatch org-auth
```

The `org-auth` agent task runs `sf org list --json` and
`sf config get target-org --json` asynchronously and writes
`docs/salesforce/org-auth.md` with the result.

## Notes

- Trailhead Playgrounds expire. If a task's org probe step starts
  failing with an auth error, log in again.
- Dev Hub orgs: authorize with the same `sf org login web` flow and
  pass the alias as the task's second argument:
  `:SfTasksDispatch apex-basics my-devhub`.
- Never paste tokens or client secrets into Neovim command lines or
  task notes; the browser login flow keeps credentials out of the
  editor.
