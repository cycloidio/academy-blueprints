# First path log: Kubernetes on one VM with K3s

Olivier builds and tests the K3s path in his Cycloid alpha workspace; Claude writes the code of `academy-app` and
`academy-blueprints`. This log records each step tried, its result, each blocker and product gap with what it waits
on, each question for the Cycloid team, and the comparison grid entries as they become known. Olivier decides the
first track from it. His walk here is not the published walk record of specs/11 §7.

Build plan: `k3s-first-path.md` and `track-assessment.md` (shared notes folder of the orchestrator session,
`k3s-first-path/`).

## Decisions

| Date | Decision | By |
|---|---|---|
| 2026-11-18 | Code lives in `cycloidio/academy-app` and `cycloidio/academy-blueprints`, local clones in `~/Projects/` | Olivier |
| 2026-11-18 | Publishing the catalog from the tester's own `academy-blueprints` is its own setup mission, never part of C1. C1 stays as specs/11 has it: `academy-app` only | Olivier |
| 2026-11-18 | Q2: the Helm chart lives in `academy-app/chart/`, published by the CI to GHCR as an OCI artifact tagged with the commit SHA; `academy-app` is a simple Node app | Olivier |
| 2026-11-18 | Q3: image and chart packages are public | Olivier |
| 2026-11-18 | Q4: no CloudFormation nor any deploy tool bound to one cloud for the C2 role; Terraform asked about (open) | Olivier |
| 2026-11-18 | Q5: the K3s Terraform is applied from a Cycloid Blueprint, never by hand: that is the day-1 target of the missions, and Olivier's own walk starts from it | Olivier |
| 2026-11-18 | Q6: region, machine size and AWS account are chosen by the prospect in the Blueprint's form | Olivier |
| 2026-11-18 | Q8: Node.js LTS, no runtime dependency, `node:test`, `node:http` | Olivier |
| 2026-11-18 | C0: the public `cycloidio/academy-blueprints` populates the catalog in C0. Not working yet; the Cycloid team is implementing it | Olivier |
| 2026-11-18 | C1 scaffolding: the platform team creates the repository for the developer, then a Blueprint sets up the app's technical stack in it | Olivier |
| 2026-11-18 | First investigation, before any build: can the kubeconfig live in AWS Secrets Manager, so that the Kubernetes Provider finds it there | Olivier |

## Cycloid format references

| Date | Reference | What it confirms |
|---|---|---|
| 2026-11-18 | Blueprint exported by Olivier from the alpha (demo, three `docker` steps) | Real file shape: top-level `actions[]` (`id`, `name`, `trigger: manual`, `workflow: <name>`) and a top-level `workflows:` map, each with `steps[]` (`id`, `type`, `params`, `depends_on`). `docker` params: `image`, `command`, `args`, `env`. Expressions with `!jq .resource.name`. Differs from `cycloid/specs/examples/*.yaml`, which put the workflow inline in the action and say they are illustrative only |
| 2026-11-18 | `cycloid` repository at `40ab160a4` (Olivier pulls it daily at 09:00), read with his go | See "What the Cycloid code shows" below. The alpha may run another version: what the alpha does wins |

### What the Cycloid code shows (cycloid `40ab160a4`, 2026-11-18)

Paths in the `cycloid` repository. Checked by hand where marked (checked); the rest from a read of the code.

- **Blueprint file.** Top-level `credentials[]`, `requirements` (`providers`, `plugins`), `property_schema[]`, `actions[]`,
  `workflows{}`, `form`, `previews`, `lifecycle_stages`, `removal_behavior` (`require_delete_first` or `allow_unlink`).
  An action's `workflow` must be a name in `workflows`; the create action is `deploy`, the delete action `destroy`
  (`packages/shared/src/blueprint-definition.ts`).
- **Kubeconfig to a `helm` step (K2).** The Kubernetes plugin's `kubeconfig` credential type is written to a file and
  `KUBECONFIG` points at it (`plugins/kubernetes/credentials/kubeconfig.yaml`, checked). A Blueprint declares it in
  `credentials: [{id, type: kubeconfig}]`; it resolves, closest first, from the Resource, a related Resource, the
  Environment, the Provider linked to the Environment, the Team, then the tenant. On the container runtime it is
  mounted read-only in the step pod (`packages/orchestration/src/step-types/container.ts`, checked). **The code
  supports K2; the probe tests it on the alpha.**
- **`helm` step parameters.** `command` (install, upgrade, rollback, uninstall), `release`, `chart` (a URL, or a path
  in the run workspace), `namespace`, `values` (a list of files, or a map of `--set` overrides), `wait` (default
  true), `create_namespace`. No `version`, no `repo`. `upgrade` runs without `--install` (registry.ts, checked).
- **Runtimes.** The container runtime runs `shell`, `helm` and `docker` steps only; a `terraform` step there fails
  `RUNNER_UNAVAILABLE` (container.ts, checked). `terraform` runs only on an opt-in local runtime. Which runtime the
  alpha uses cannot be read from the code.
- **No Git source.** A Blueprint `source` (the Git checkout of step code into the run workspace) is refused at save and
  at dispatch until VCS access checks exist (blueprint-definition.ts, checked). So no step can read Terraform code or a
  chart from a repository; a `helm` step can only use a chart URL.
- **Terraform state.** Nothing injects a backend or state; the code must bring its own.
- **AWS OIDC.** `aws-oidc` gives the step `CYCLOID_OIDC_TOKEN` and `AWS_ROLE_ARN` (`plugins/aws/credentials/aws-oidc.yaml`,
  checked). It does not set `AWS_WEB_IDENTITY_TOKEN_FILE`, which the AWS SDK and the Terraform AWS provider read; to
  test.
- **Expressions.** `.resource.{name,slug,properties}`, `.environment.{name,slug}`, `.preview.{slug,number}`,
  `.fields.<id>.value` for form values, `.steps.<id>.outputs.*` from upstream steps. `.forms` and `.credentials` are
  refused in workflows.
- **Previews and builds.** `previews: true` and `promotes_as: app_ref` on one property are implemented; the deploy of a
  preview on a pull request was not traced.
- **Expiry.** `lifecycle_stages.ttl_triggers: [{stage, ttl}]`, `ttl` like `7d`; also a per-Resource auto-destroy.
- **Blueprint sources.** Upload of a file bundle (entry `blueprint.yaml`) is implemented; a Git sync of a source
  repository was not found.

## Ideas to confirm with Olivier (not decisions)

- **C0, public catalog source.** The catalog comes from the public `cycloidio/academy-blueprints` added as a Blueprint
  source, with no Git connection. To observe: a source accepts a plain public repository URL; a source can be pinned
  to a tag; assigning it to the team works.
- **Scaffolding Blueprint in C1.** The platform team creates an empty repository by hand; a Blueprint copies the
  `academy-app` template into it with the service name filled in, with `git clone` and `git push` in a command step.
  To observe: which step types the alpha offers; whether a command step can receive a Git credential that may write;
  whether the Cycloid GitHub App may write workflow files.
- **`academy-app` CI.** No repository variable or secret (image name from the repository name, lowercased; tag from
  the commit SHA; built-in token with `packages: write` declared in the workflow); no third-party action (GitHub's
  own checkout, then plain `docker build` and `docker push`). To observe: whether the first run starts by itself in a
  repository created from the template; whether the package is private by default.

## Steps

| # | Date | Step | Result | Settles / waits on |
|---|---|---|---|---|
| T2 | 2026-11-18 | Blueprint with one `terraform` step (`command: validate`), action `deploy`, in the alpha | Failed in 835 ms, `CY-DP-0004`: "the container runtime runs shell, helm and docker steps only; terraform step tf was not executed". The alpha runs the container runtime | Confirms G2 |
| T1 | 2026-11-18 | Create a Kubernetes Provider in the alpha and add a kubeconfig to it | No kubeconfig option offered on the Provider; Secrets Manager not tried as a result | G8 |

## Blockers and product gaps

| Gap | Seen at step | Waits on |
|---|---|---|
| G1. No Git source for step code: a `terraform` step has no way to get its code, a `helm` step only a chart URL | Code read, 2026-11-18 | Cycloid team (VCS access check, specs 04 §3). Blocks C3 as planned (cluster created by a `terraform` step from Blueprint code) |
| G2. `terraform` steps do not run on the container runtime | Code read; confirmed on the alpha by T2, 2026-11-18 | Cycloid team. The alpha runs the container runtime: no Blueprint can use a `terraform` step today, on either track (C3 cluster, VM, the C2 check of step 7) |
| G3. No Terraform state backend from Cycloid; the plan assumed hosted state (K:43-47) | Code read, 2026-11-18 | Cycloid team |
| G4. `helm upgrade` without `--install`: the same action cannot both create and update a release; the plan's M1 deploy then M2 update need two workflows (`deploy` = install, update = upgrade) | Code read, 2026-11-18 | Probe confirms; question to the Cycloid team (the usual pattern is `upgrade --install`) |
| G5. `helm` step has no `version` parameter: the version must be in the chart reference | Code read, 2026-11-18 | Probe tests the OCI form `oci://...:<version>` |
| G6. `aws-oidc` does not set `AWS_WEB_IDENTITY_TOKEN_FILE` | Code read, 2026-11-18 | Test at C2 (step 7) |
| G7. AWS Secrets Manager as a credential store: in the specs (07/10 §6, Cycloid stores the ARN reference), not available in the code (`AVAILABLE_CREDENTIAL_BACKENDS` is `cycloid-db` only, external backends come with FS-1937). It is a tenant-level backend Cycloid writes to, so whether a credential can point at a secret the cluster's VM wrote in the prospect's account is not said | Code read, 2026-11-18 | Olivier's check in the alpha UI; Cycloid team (FS-1937 date, reference to an existing secret) |
| G8. A Provider offers only the credential types its Provider Blueprint lists in `provides_credential_types`, plus the built-ins; plugin types such as `kubeconfig` (and `aws-oidc`) are filtered out otherwise. In the code, only test fixtures and mock providers set that list; no production path sets it from a Blueprint or a plugin (`apps/web/app/utils/credentialTypes.ts`, `packages/database/src/schema/blueprints.ts`, `packages/fixtures/src/loader.ts`). Explains T1 | T1, 2026-11-18 | Cycloid team. Real alternative in the credential hierarchy: a `kubeconfig` credential on the Environment (default resolution walk: Resource, Environment, Provider, Team, tenant), to test |

## Questions for the Cycloid team

| Question | Asked | Answer |
|---|---|---|
| When will `terraform` (and `ansible`) steps run on the container runtime the alpha uses (T2)? | Not yet | |
| When does a Blueprint `source` (Git checkout of step code) become available? Until then, how is Terraform code meant to reach a `terraform` step? | Not yet | |
| Does Cycloid provide Terraform state, or does the Blueprint bring its own backend? | Not yet | |
| Should `helm upgrade` take `--install`, so one action creates and updates a release? | Not yet | |
| How does `aws-oidc` reach the Terraform AWS provider (no `AWS_WEB_IDENTITY_TOKEN_FILE`)? | Not yet | |
| How does a Blueprint source get into a workspace: bundle upload only, or a Git repository URL? | Not yet | |
| Provider credential contract (G8): how is `provides_credential_types` set on a real Provider Blueprint, so a Kubernetes Provider offers `kubeconfig` and an AWS Provider `aws-oidc`? | Not yet | |
| AWS Secrets Manager backend (FS-1937): when, and can a credential reference an existing secret in the customer's account (ARN) with the Provider's AWS role, rather than one Cycloid writes? | Not yet | |

## Comparison grid entries (K3s)

Rows from `track-assessment.md` §3, filled as the walk shows them.

| Row | K3s observation | Step |
|---|---|---|
