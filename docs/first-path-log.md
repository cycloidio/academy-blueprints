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
| 2026-11-18 | D1: until Cycloid runs `terraform` steps and takes Blueprint files from Git, C3 runs Terraform inside a `shell` step with the official Terraform image, which fetches the public `academy-blueprints` code at a fixed version; marked in the Blueprint and here as the part to replace. `shell` rather than `docker` because only a `shell` step returns outputs (the VM address becomes a Resource property); both run the image in the same kind of container | Olivier |
| 2026-11-18 | D2: Terraform state in an S3 bucket in the prospect's account, created in C2 | Olivier |
| 2026-11-18 | D3: the C3 run reaches AWS by OIDC; Terraform's AWS provider exchanges the token itself. Needs Cycloid's issuer URL, audience and subject format | Olivier |
| 2026-11-18 | D4: the VM writes a kubeconfig limited to the `academy` namespace into Secrets Manager; the person pastes it into the Environment's credentials in Cycloid | Olivier |
| 2026-11-18 | D5: the app's address is a hostname through sslip.io (`<slug>.<vm-ip>.sslip.io` or similar) on K3s's Traefik; a `shell` step returns it as a Resource property | Olivier |
| 2026-11-18 | C2 setup: one pasted AWS CLI block in AWS CloudShell (state bucket, permissions boundary, OIDC provider, `academy-` role), no Terraform; a second block removes it | Olivier |
| 2026-11-19 | Every name a prospect sees in AWS or Kubernetes starts with `cycloid-academy`, so they know it comes from Cycloid: state bucket `cycloid-academy-tfstate-<account>`, state keys `cycloid-academy/clusters/<slug>/`, AWS resources and tags `cycloid-academy-<name>-...`, IAM test user `cycloid-academy` (unique per account only), Kubernetes namespace `cycloid-academy` (the plan says `academy`) and `cycloid-academy-welcome`, tag `cycloid-academy-cluster-v0.2.0`. Repository, folder and chart names unchanged (open) | Olivier |
| 2026-11-18 | Olivier's first C3 tests use an AWS access key on the `dev` Environment (test IAM user with a limited policy); OIDC (D3) stays the mission's way and replaces it once Cycloid's issuer, audience and subject are known | Olivier |
| 2026-11-18 | Both repositories keep `master` as their default branch; the missions' text says `master` where the plan says `main` | Olivier |
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

### Cycloid product team answer (2026-11-18, checked against their code of that day)

Beta date given: 7 Dec 2026, after the Academy launch of 1 Dec.

| Topic | Today on the alpha | Plan |
|---|---|---|
| Step types | Only `helm`, `shell`, `docker` run. `terraform` and `ansible` do not | Beta (open pull request, not merged) |
| Network | Steps run in the alpha cluster and reach public addresses only. The K3s API (6443) must answer on the VM's public IP, with that IP in the certificate (`--tls-san <public-ip>`) | |
| Git source for Blueprint files | None: charts and values come from a URL or inline in the Blueprint | Beta, not started |
| Credential lookup | By declared type, closest first: Resource, Environment, the Environment's Providers, Team, workspace. Every declared credential reaches every step of the run | Per-step credential: not planned |
| `helm` + `kubeconfig` | Works. `KUBECONFIG` points at a file holding exactly the pasted kubeconfig; its current context is used. The helm image has no cloud tools: a plain kubeconfig with a token or certificate. K3s's default kubeconfig is fine | |
| What a step gets per credential type | AWS access key: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`. Azure service principal: `ARM_*`. GCP service account: key file in `GOOGLE_APPLICATION_CREDENTIALS`. OIDC types: the raw token only, no exchange for cloud credentials | Exchange: not planned |
| Ansible until the beta | Their suggestion: a `docker` step with one's own Ansible image, which gets the same variables | |
| Run creating a credential or Provider | Not possible. Outputs only become Resource properties | Not planned |
| Their PoC suggestion for the kubeconfig | Install K3s on the VM, copy `/etc/rancher/k3s/k3s.yaml`, replace `127.0.0.1` with the public IP, paste it into Cycloid as a kubeconfig credential | |
| Kubernetes Provider form | None yet. A kubeconfig is pasted into one field, checked only for being non-empty, no connection test | Form: before the beta. Connection test: not planned |
| Address of a Helm-deployed Resource | Only release status and revision are reported. Their suggestion: pick the hostname per environment (K3s's Traefik plus a wildcard DNS such as sslip.io, `app-dev.<vm-ip>.sslip.io`), pass it to the chart, and a small `shell` step returns it as an output, which becomes a Resource property | Address reporting: not planned |
| Chart location | A public URL: an OCI registry address or a `.tgz` link. No version setting, so a `.tgz` link is the sure way to pin | Charts from the Blueprint's Git repository: beta, not started. Version setting, named repo, private registry: not planned |

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
| B1 | 2026-11-18 | `academy-app` written (commit `b08c8e6`, local): Node 26 LTS app, `node:test`, Dockerfile on `node:26.13.1-alpine` by digest, non-root; Helm chart routed by hostname (`ingress.host`, Traefik); CI on `ubuntu-24.04` with `actions/checkout` v7.0.1 by SHA, `docker`, `helm`, no secret | Checked by Claude on a laptop: 5 tests pass, image builds and runs as uid 1000, page shows commit and environment; chart lints and renders with `alpine/helm:3.22.1` (the image of Cycloid's `helm` step). Not pushed; CI not run | D:828-837 |
| B2 | 2026-11-18 | Push `academy-app` to `master` (Olivier's go) | Refused: the cycloidio organisation ruleset on `master` requires a pull request with one approval and forbids non-fast-forward pushes. Pushed to branch `app-ci` instead, draft PR cycloidio/academy-app#1; its push starts the first CI run | G12 |
| B5 | 2026-11-18 | `academy-cluster/blueprint.yaml` (C3, stopgap D1): form (region, machine size, AWS account ID for the key test); credentials `aws-oidc` and `aws-access-key`, both optional; `deploy` = one `shell` step in `hashicorp/terraform:1.17.2` by digest: OIDC token to `AWS_WEB_IDENTITY_TOKEN_FILE` when present, `git clone` of this repository at tag `academy-cluster-v0.1.0`, `terraform init` on bucket `academy-tfstate-<account>` key `academy/clusters/<slug>/`, `apply`, wait up to 15 min for the cluster page, outputs to properties; `destroy` reuses region and bucket from the properties. `aws-setup/test-key-setup.sh` and `test-key-remove.sh`: state bucket and a test IAM user with a limited policy and one access key (Olivier's test only, decision 2026-11-18) | Checked by Claude: both Blueprints parse as YAML; the C3 scripts parse in the image's `sh`; the AWS CLI scripts pass `bash -n`. Not run; needs this repository pushed with the tag | D1 to D4 |
| B7 | 2026-11-19 | `academy-app-kubernetes/blueprint.yaml` (M1, M2): `kubeconfig` credential; form (full commit SHA, cluster hostname suffix copied from the cluster Resource, message); `deploy` = `helm install` of `oci://ghcr.io/cycloidio/charts/academy-app:0.1.0-g<commit>` (release = Resource slug, host `<slug>-<environment>.<suffix>`), then a `shell` step returning `url` and `app_ref` (`promotes_as: app_ref`); `update` = `helm upgrade`; `destroy` = `helm uninstall` | Parses as YAML. Not run; needs the GHCR packages public and the OCI form of the chart reference to work | K6, K8, G4, G5, G10 |
| T7 | 2026-11-19 | Probe "Deploy podinfo (OCI reference)" | **Success**: `oci://ghcr.io/stefanprodan/charts/podinfo:6.17.0` pulled, release `probe-oci` deployed. A version in the OCI reference works | G5 worked around: `oci://…:<version>` pins the chart |
| T8 | 2026-11-19 | Cluster Resource after C3 | Properties shown: `shell` step outputs become Resource properties | G10 workaround works |
| T9 | 2026-11-19 | GHCR packages `academy-app` and `charts/academy-app` made public by Olivier | Done | Q3 |
| T10 | 2026-11-19 | M1 first try: `academy-app-kubernetes` deployed | Run never started: `!tpl` expressions using `environment.slug` failed to evaluate ("evaluation error") in the helm `values` and the shell script; `fields.commit.value` in the chart reference resolved. Probable cause (code read, to confirm): `.environment` is null when the Resource is not bound to an Environment. Fix: `environment_scope: required` in the Blueprint | |
| T6 | 2026-11-19 | Kubeconfig copied from Secrets Manager into a `kubeconfig` credential on `demo-team`; `probe-helm` pasted in the portal, action "Deploy podinfo (chart archive URL)" | **Success**: release `probe`, namespace `cycloid-academy`, status `deployed`, revision 1, chart from a `.tgz` URL. A `helm` step reaches a K3s cluster created by a Blueprint, with the namespace-limited kubeconfig, from a team credential | **K2 settled (P:280)**: a Kubernetes mission can deploy |
| T5 | 2026-11-19 | C3: `academy-cluster/blueprint.yaml` pasted in the portal as platform team (no Git sync yet), "Create the cluster" run | The secret `cycloid-academy-cluster-kubeconfig` exists in Secrets Manager (Resource slug `cluster`); the cluster page reads "Your cluster is ready. No app yet.". Resource properties from the `shell` step outputs: to confirm | C3 end to end on the alpha, D1 stopgap |
| T4 | 2026-11-19 | Add the AWS access key (test) as a credential on the `dev` Environment | Not possible for Olivier at the moment; added on the team `demo-team` instead, which is in the lookup (Resource, Environment, Providers, Team, workspace) | G13 |
| B6 | 2026-11-19 | Rename to `cycloid-academy` (decision of 2026-11-19). Found: commit `8009679` also took in `academy-hello/` and `academy-environment/`, two Blueprints Claude did not write that were in the folder (created 2026-11-18 at 10:34 and 13:53); they are in PR #1 | Checks re-run: `terraform fmt`, `validate`, scripts parse. Not run in Cycloid or AWS | Olivier: drop them. Removed from the branch in `6cb3b7d`, still on disk, untracked |
| B4 | 2026-11-18 | Olivier merged cycloidio/academy-app#1 (merge commit `5610f2d`) | CI on `master` green: image `ghcr.io/cycloidio/academy-app:5610f2d4cb17b309320a95cbc2f02724afb23273`, chart `oci://ghcr.io/cycloidio/charts/academy-app:0.1.0-g5610f2d4cb17b309320a95cbc2f02724afb23273` | |
| B3 | 2026-11-18 | `academy-cluster/terraform` written (local): own VPC and public subnet; security group 80, 443, 6443 only, no SSH, no key pair; Elastic IP created before the machine; Ubuntu 24.04 `t3.medium` (form may pick t3/t3a medium or large), IMDSv2 with hop limit 1, encrypted disk; machine role may only `PutSecretValue` on its one secret; secret created empty, no recovery window; S3 backend by partial config (D2). First boot: K3s `v1.37.2+k3s1` from the release's `install.sh` checked by SHA-256, `--tls-san` the public IP; namespace `academy`, service account bound to the built-in `admin` ClusterRole in that namespace only, its token; NetworkPolicy blocking 169.254.169.254; kubeconfig (server `https://<ip>:6443`, cluster CA, token, current context in `academy`) written to the secret with the AWS CLI snap; then the default page "Your cluster is ready. No app yet." on the bare IP. Outputs: `public_ip`, `url`, `hostname_suffix` (`<ip>.sslip.io`), `kubeconfig_secret_name`, `region` | Checked by Claude: `terraform fmt -check` and `validate` pass (Terraform 1.17.2, AWS provider 6.73, lock file for linux amd64/arm64 and darwin arm64); first-boot template renders and passes `bash -n`. Not applied: it runs from the C3 Blueprint (Q5) | P:121, K:123-132 |
| T3 | 2026-11-18 | First CI run of `academy-app` (branch `app-ci`, PR #1) | Olivier: both jobs green, image and chart published under the names the summary gives; the image pulled from GHCR runs on his laptop and shows its commit. Started by itself on the first push. Package visibility not checked yet | D:960 (CI runs at once) |
| T2 | 2026-11-18 | Blueprint with one `terraform` step (`command: validate`), action `deploy`, in the alpha | Failed in 835 ms, `CY-DP-0004`: "the container runtime runs shell, helm and docker steps only; terraform step tf was not executed". The alpha runs the container runtime | Confirms G2 |
| T1 | 2026-11-18 | Create a Kubernetes Provider in the alpha and add a kubeconfig to it | No kubeconfig option offered on the Provider; Secrets Manager not tried as a result | G8 |

## Blockers and product gaps

| Gap | Seen at step | Waits on |
|---|---|---|
| G1. No Git source for step code: a `terraform` step has no way to get its code, a `helm` step only a chart URL | Code read, 2026-11-18 | Cycloid: beta (7 Dec), not started. Blocks C3 as planned (cluster created by a `terraform` step from Blueprint code) |
| G2. `terraform` steps do not run on the container runtime | Code read; confirmed on the alpha by T2, 2026-11-18 | Cycloid: beta (7 Dec, open pull request). Until then no Blueprint can use a `terraform` or `ansible` step, on either track (C3 cluster, VM, the C2 check of step 7) |
| G3. No Terraform state backend from Cycloid; the plan assumed hosted state (K:43-47) | Code read, 2026-11-18 | Cycloid team |
| G4. `helm upgrade` without `--install`: the same action cannot both create and update a release; the plan's M1 deploy then M2 update need two workflows (`deploy` = install, update = upgrade) | Code read, 2026-11-18 | Probe confirms; question to the Cycloid team (the usual pattern is `upgrade --install`) |
| G5. `helm` step has no `version` parameter: the version must be in the chart reference | Code read, 2026-11-18 | Probe tests the OCI form `oci://...:<version>` |
| G6. OIDC credential types give the step the raw token only; Cycloid does not exchange it for cloud credentials | Code read; confirmed by the Cycloid team, 2026-11-18 | Not planned. The step does the exchange itself (for Terraform, the AWS provider's web identity settings) |
| G7. AWS Secrets Manager as a credential store: in the specs (07/10 §6, Cycloid stores the ARN reference), not available in the code (`AVAILABLE_CREDENTIAL_BACKENDS` is `cycloid-db` only, external backends come with FS-1937). It is a tenant-level backend Cycloid writes to, so whether a credential can point at a secret the cluster's VM wrote in the prospect's account is not said | Code read, 2026-11-18 | Cycloid team (FS-1937 date). Moot for the day-1 path while a run cannot create a credential (G9): the kubeconfig is pasted by a person |
| G8. A Provider offers only the credential types its Provider Blueprint lists in `provides_credential_types`, plus the built-ins; plugin types such as `kubeconfig` (and `aws-oidc`) are filtered out otherwise. In the code, only test fixtures and mock providers set that list; no production path sets it from a Blueprint or a plugin (`apps/web/app/utils/credentialTypes.ts`, `packages/database/src/schema/blueprints.ts`, `packages/fixtures/src/loader.ts`). Explains T1 | T1, 2026-11-18 | Cycloid: Kubernetes Provider form before the beta. Meanwhile a `kubeconfig` credential on the Environment (lookup: Resource, Environment, Providers, Team, workspace), to test |
| G9. A run cannot create or update a credential or a Provider; outputs only become Resource properties. The kubeconfig of a cluster a Blueprint creates must be pasted into Cycloid by a person | Cycloid team, 2026-11-18 | Not planned |
| G10. A `helm` step reports no address; the Resource gets one only from a `shell` step output | Cycloid team, 2026-11-18 | Not planned |
| G11. A pasted kubeconfig is checked only for being non-empty, no connection test | Cycloid team, 2026-11-18 | Not planned |
| G12. Organisation rulesets can forbid direct pushes to the default branch (cycloidio does: pull request with one approval). Any mission step that pushes to a prospect's default branch (the C1 scaffolding Blueprint's `git push`) fails under such a rule; pushing a branch and opening a pull request works under it | B2, 2026-11-18 | Olivier: design of the C1 scaffolding step |
| G13. A credential cannot be added to an Environment in Olivier's alpha workspace (2026-11-19); the team works instead. The kubeconfig of each cluster will then sit on the team, and which one a step gets when the team holds two (two clusters) is not known yet | T4, 2026-11-19 | Cycloid team: Environment credentials; Kubernetes Provider form (before the beta) |

## Questions for the Cycloid team

| Question | Asked | Answer |
|---|---|---|
| When will `terraform` (and `ansible`) steps run on the container runtime the alpha uses (T2)? | 2026-11-18 | Beta, 7 Dec (open pull request) |
| When does a Blueprint `source` (Git checkout of step code) become available? Until then, how is Terraform code meant to reach a `terraform` step? | 2026-11-18 | Beta, not started; until then URL or inline only |
| Does Cycloid provide Terraform state, or does the Blueprint bring its own backend? | Not yet | Still open |
| Should `helm upgrade` take `--install`, so one action creates and updates a release? | Not yet | Still open |
| How does `aws-oidc` reach the Terraform AWS provider (no `AWS_WEB_IDENTITY_TOKEN_FILE`)? | 2026-11-18 | Raw token only, no exchange, not planned |
| How does a Blueprint source get into a workspace: bundle upload only, or a Git repository URL? | Not yet | |
| Provider credential contract (G8): how is `provides_credential_types` set on a real Provider Blueprint, so a Kubernetes Provider offers `kubeconfig` and an AWS Provider `aws-oidc`? | 2026-11-18 | Kubernetes Provider form being built, before the beta; AWS Provider not answered |
| Can a run create or update a credential or a Provider? | 2026-11-18 | No, not planned (G9) |
| How does a Helm-deployed Resource get its address? | 2026-11-18 | Not reported; `shell` step output (G10) |
| For D3: Cycloid's OIDC issuer URL on the alpha, the audience value, and the subject claim format (to write the AWS trust policy) | Not yet | |
| How does an app Blueprint read a property of another Resource (the cluster's IP, for the sslip.io hostname): a form source listing Resources, a relation in expressions, or a form field the person fills? | Not yet | |
| AWS Secrets Manager backend (FS-1937): when, and can a credential reference an existing secret in the customer's account (ARN) with the Provider's AWS role, rather than one Cycloid writes? | Not yet | |

## Comparison grid entries (K3s)

Rows from `track-assessment.md` §3, filled as the walk shows them.

| Row | K3s observation | Step |
|---|---|---|
