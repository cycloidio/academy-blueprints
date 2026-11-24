# Trial workspace setup (Kubernetes track)

What Olivier does in Cycloid when he creates a trial workspace, before the tester starts C0. It details step 2 of the
Academy runbook "Provision a workspace" (cycloid-academy `specs/14-operations-runbooks.md` §2: "template of the
track"). Walked on the alpha on 2026-11-24 (`docs/first-path-log.md`, T26 and T27).

What a template cannot do (G26): it creates the teams only. The plugins, the catalog repository, its Blueprint sources
and publishing are done by hand, in this order. Environments stay with the tester (C0); Providers and credentials too
(C2, C3).

## 0. Once per Cycloid instance: the workspace template

In the Admin Panel, create a workspace template named "Academy Build" (the name the Academy runbook uses) with the
content of
[`trial-workspace-template.json`](trial-workspace-template.json): the teams `Engineering`, then `Platform Team` and
`Development Team` under it. No label groups. `blueprintRefs` stays empty: it only checks that Blueprints exist and
adds none, so a new workspace would report ours as missing.

## 1. Create the workspace from the template

Admin Panel → Workspaces → Create workspace, template "Academy Build" (name, slug and the other fields as in the
Academy runbook). Check: the workspace has the three teams, `Platform Team` and `Development Team` under `Engineering`.

## 2. Get the workspace's jobs run

On the alpha, runners do not run steps yet: a platform worker runs the jobs of the workspaces named in its setting
(`CY_WORKER_TENANT_SLUGS`), and the runs of any other workspace stay Pending (G27). Ask the Cycloid team to add the
new workspace's slug to that list. Later, a runner per workspace (Settings → Runners; Academy runbook step 4).

Check: a run started in the workspace leaves Pending.

## 3. Enable the Kubernetes and AWS plugins

Settings → Plugins → **Kubernetes** → Enable, and approve its permissions. The same for **AWS**.

- Kubernetes: Cycloid refuses to publish a Blueprint that requires a credential of a plugin the workspace has not
  enabled. Academy App (Kubernetes) requires a `kubeconfig` credential, so its publish fails without it.
- AWS: the missions C2 and C3 add AWS credentials and a Provider; the AWS credential types do not exist in the
  workspace without the plugin.

Check: both show as Enabled on Settings → Plugins.

## 4. Add the catalog repository

Repositories → Add repository: `https://github.com/cycloidio/academy-blueprints`, with the shared read-only token
(the Cycloid service account's GitHub token, "Public repositories (read-only)"). Type the token only into this form,
never into a file, a ticket or a message. Cycloid requires a token even for a public repository, and GitHub refuses a
placeholder (T17).

## 5. Add the three Blueprint sources

Settings → Blueprint management → Add Blueprint source, three times, on that repository:

| Folder | Blueprint it brings | Owner team |
|---|---|---|
| `academy-environment` | Academy Environment | Platform Team |
| `academy-cluster` | Academy cluster | Platform Team |
| `academy-app-kubernetes` | Academy App (Kubernetes) | Development Team |

One source per folder, never one source on `/`: that would also bring the folders that are not for testers (such as
the Helm probe). Branch `master` (`first-path` while the Kubernetes path is being tested). Auto-sync on, **no webhook**: Sync now and
the daily check keep the drafts in step (decision 2026-11-20). Check: each source's scan finds one Blueprint.

## 6. Publish the three drafts

Open each Blueprint and Publish (it cuts v1). Check: the three Blueprints show a published v1. Academy Environment is
not listed in the catalog (Environment Blueprints never are); it is used by Environments → Create environment in C0.

If a publish says "Credential type … is provided by the … plugin, which is not enabled for this tenant", step 3 was
skipped: enable that plugin and publish again.

## Not yet

- The GitHub plugin (G19), for linking repositories and pull request previews (C6, M8): not in the alpha yet.
