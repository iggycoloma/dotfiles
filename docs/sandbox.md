Claude Code Bash Sandbox Setup

Execution plan for enabling Claude Code's built-in Bash sandbox in this
dotfiles repo. Run from a Claude Code session rooted in ~/.dotfiles -- that
is where claude-code/settings.json (symlinked to ~/.claude/settings.json) and
the dev-container configs live.

Context
Claude Code's permission analyzer prompts on every Bash command it cannot
statically decompose -- here-docs (python3 - <<'EOF'), pipes, command
substitution, IFS=. These cannot be allow-listed because there is no stable
command prefix to match. The current settings.json allow list
(~80 Bash(prefix:*) rules) cannot cover them.

Separately, credential protection today is Read()/Write()/Edit() deny globs.
Those gate Claude's file tools and recognized Bash file-commands
(cat/head/sed) but NOT arbitrary subprocesses -- a
python3 -c "open('~/.ssh/id_rsa').read()" is not caught.

Fix: enable Claude Code's built-in Bash sandbox in auto-allow mode. The OS
boundary (Seatbelt on macOS, bubblewrap on Linux) replaces the per-command
prompt, so complex Bash just runs -- contained. This eliminates the prompts
AND closes the subprocess credential gap. Investigation confirmed the
existing pre-security.sh hook is passive on benign commands (exit 0, silent)
-- it is not the prompt source.

Decisions
Three decisions made during planning, recorded here so future-me does not
relitigate them.

1. Skip the @anthropic-ai/sandbox-runtime npm package (the seccomp filter
   that blocks Unix domain sockets). The active workflow here uses ssh-agent
   for git push, which would require allowlisting SSH_AUTH_SOCK back through
   anyway -- collapsing the main benefit (ssh-agent abuse prevention).
   Remaining surface (Docker socket, D-Bus, local IPC sockets) is narrow:
   these devcontainers do not mount /var/run/docker.sock, do not expose
   D-Bus, and do not run local services on Unix sockets. Adding Node.js +
   npm to the install footprint for marginal gain is not worth it. The
   /sandbox Dependencies tab will report the seccomp filter as missing --
   expected. Revisit if /var/run/docker.sock ever gets mounted, or if local
   Unix-socket services start running inside the sandbox boundary.

2. Skip the /etc/claude-code/managed-settings.json file. Settings precedence
   is managed > CLI > local > project > user, and objects deep-merge across
   scopes -- adding the managed layer later is non-destructive. For this
   single-developer repo, putting failIfUnavailable: true directly in user
   settings is strict everywhere (Seatbelt is always available on macOS, so
   true never spuriously fires on host; Linux containers will have
   bubblewrap from this same change). The managed-settings layer's only
   added value is tamper-resistance against user (or agent) edits to the
   user settings file, which is overkill for a single-dev setup.

3. No custom Dockerfile. The repo bootstraps via install.sh ->
   bootstrap/packages.sh, which already installs bubblewrap in the apt and
   apk arrays (gated on DOTFILES_NO_AI_TOOLS != 1). Add socat next to it on
   the same lines instead of introducing Dockerfiles. Keeps the bootstrap-
   from-install.sh architecture intact.

Dev containers use the same ~/.dotfiles repo and run privileged. So one
shared settings.json works everywhere; the only container-specific work is
installing socat alongside the existing bubblewrap install. No
enableWeakerNestedSandbox is needed (that is only for unprivileged
containers).

Execution steps
Run these from the dotfiles-repo session.

Step 1a -- add the sandbox block to settings.json
Edit claude-code/settings.json (symlinked to ~/.claude/settings.json). Add
this top-level key alongside permissions, hooks, etc.:

"sandbox": {
  "enabled": true,
  "autoAllowBashIfSandboxed": true,
  "failIfUnavailable": true,
  "allowUnsandboxedCommands": true,
  "excludedCommands": [
    "obsidian *"
  ],
  "filesystem": {
    "denyRead": [
      "~/.ssh",
      "~/.aws",
      "~/.gnupg",
      "~/.azure",
      "~/.config/gcloud",
      "~/.config/gh",
      "~/.config/hub",
      "~/.config/heroku",
      "~/.config/doctl",
      "~/.stripe",
      "~/.minikube",
      "~/.dotfiles-state",
      "~/.docker/config.json",
      "~/.kube/config",
      "~/.npmrc",
      "~/.netrc",
      "~/.git-credentials",
      "~/.pgpass",
      "~/.my.cnf",
      "~/.pypirc",
      "~/.gem/credentials",
      "~/.composer/auth.json",
      "~/.m2/settings.xml",
      "~/.m2/settings-security.xml",
      "~/.gradle/gradle.properties",
      "~/.mongorc.js"
    ],
    "denyWrite": [
      "~/.ssh",
      "~/.aws",
      "~/.gnupg",
      "~/.bashrc",
      "~/.zshrc",
      "~/.zshenv",
      "~/.zprofile",
      "~/.profile"
    ]
  },
  "network": {
    "allowedDomains": [
      "github.com",
      "*.githubusercontent.com",
      "api.github.com",
      "registry.npmjs.org",
      "*.npmjs.org",
      "pypi.org",
      "files.pythonhosted.org"
    ]
  }
}

Key rationale:

enabled / autoAllowBashIfSandboxed: true -- auto-allow mode; this is what
stops the analyzer prompts. Both stated explicitly even though
autoAllowBashIfSandboxed already defaults to true (survives a future default
change).

failIfUnavailable: true -- strict everywhere. On macOS the host's Seatbelt
is always available, so true never spuriously trips on host. On Linux,
containers built from this repo will have bubblewrap + socat from Step 2.
If a future image accidentally drops those packages, Claude Code refuses to
start rather than silently running unsandboxed -- the failure surface we
want.

allowUnsandboxedCommands: true -- keeps the escape hatch; commands that
genuinely cannot be sandboxed (docker, watchman, some go CLIs on Seatbelt)
retry through the normal permission flow rather than failing outright.

excludedCommands: ["obsidian *"] -- the obsidian CLI talks to the Obsidian
app over local IPC (socket/localhost), which the sandbox blocks. Excluded
commands run outside the sandbox. Host-only concern; no Obsidian app runs in
containers.

filesystem.denyRead -- credential dirs/files enforced at the OS level for
ALL sandboxed Bash subprocesses. Mirrors the existing Read() deny list,
keeping only the path-prefix entries the OS can enforce (see Credential
protection below). Build-cache dirs (~/.cargo, full ~/.m2, full ~/.gradle)
are deliberately NOT denied -- only their credential files are -- so
toolchains still read cached deps inside the sandbox.

denyWrite -- shell rc files + credential dirs; the docs flag shell-rc writes
as a privilege-escalation path. Mostly belt-and-suspenders (default write
boundary is already cwd-only).

network.allowedDomains -- starter list so routine git/npm/pip traffic does
not prompt. Any new domain prompts once and can be added. Kept narrow on
purpose (the proxy does not inspect TLS, so broad domains are exfiltration
paths).

Note on credential FILES the sandbox cannot wholesale-deny
(~/.kube/config, ~/.docker/config.json): denying read of these means
kubectl/docker cannot authenticate inside the sandbox. docker is
sandbox-incompatible anyway; meaningful kubectl work would use the
unsandboxed escape hatch. This is the correct posture.

Step 1b -- add two permissions.allow entries
"Bash(obsidian:*)",
"Bash(python3:*)"

Bash(obsidian:*) -- because obsidian is in excludedCommands it runs outside
the sandbox and goes through the normal permission flow; without an allow
rule it prompts every time. The vault CLAUDE.md confirms it is invoked as
obsidian <subcommand>.

Bash(python3:*) -- covers bare python3 and here-docs on the unsandboxed
fallback path (currently only Bash(python3 -c:*) exists).

Step 2 -- add socat to bootstrap/packages.sh
The repo does not use custom Dockerfiles -- packages are installed by
install.sh -> bootstrap/packages.sh. bubblewrap is already added in the apt
(line 510) and apk (line 627) arrays, gated on DOTFILES_NO_AI_TOOLS != 1.
Add socat to those same calls:

  apt block (around line 510):
    packages+=("bubblewrap" "socat")

  apk block (around line 627):
    packages+=("bubblewrap" "socat")

No Homebrew change -- macOS uses Seatbelt; bubblewrap and socat are
irrelevant. The existing _apt_installed / _apk_installed idempotency loops
already handle the new package -- re-runs are no-ops once installed.

Skipped: npm install -g @anthropic-ai/sandbox-runtime (the seccomp filter
that adds Unix-domain-socket blocking). See Decision 1 above for rationale.

Conditional: if a container ever reports
sysctl kernel.apparmor_restrict_unprivileged_userns as 1, add the AppArmor
bwrap profile from the sandboxing docs. Privileged containers normally do
not need this.

Step 3 -- commit
Single conventional commit for both file changes:
  feat(claude-code): enable Bash sandbox with OS-level credential isolation

Step 4 -- restart Claude Code and run verification
Settings reload on startup. Verification steps are below.

Credential protection -- what is and is not preserved
Verified against the docs: sandbox.filesystem.denyRead merges with Read()
deny rules into the OS sandbox boundary. But the two pattern syntaxes
differ:

Directory/file-path deny rules (~/.ssh/**, ~/.kube/config, ...) translate to
OS-enforced subtree denies -- covered by the denyRead list in Step 1a.

Recursive/substring glob deny rules (**/*.pem, **/*secret*, **/credentials*,
.env, **/*.tfvars, ...) cannot become OS path-prefix boundaries. They still
fully protect the Read/Edit/Write TOOLS, but not sandboxed Bash subprocesses
reading such files INSIDE the working directory.

Residual gap and mitigation: in-project .env / *.pem / *secret* files
cannot be OS-blocked without blocking the project itself. The
pre-security.sh PreToolUse hook remains the defense -- it inspects the Bash
command string before execution and emits ask/deny for sensitive paths.
Keep it. Keep all existing Read()/Write()/Edit() deny globs unchanged --
they still fully gate the file tools. Practice: keep real secrets out of
project trees.

Unix-socket residual gap: without @anthropic-ai/sandbox-runtime, sandboxed
Bash can connect to Unix domain sockets on the host. In this setup that
means ssh-agent (allowlisted anyway for git push), D-Bus (not exposed),
docker.sock (not mounted), and any local Unix-socket services (none
currently). Re-evaluate if any of those change.

Optional hardening (verify first): the sandboxing docs mention
CLAUDE_CODE_SUBPROCESS_ENV_SCRUB to strip Anthropic/cloud credentials from
sandboxed-subprocess environment variables (denyRead only covers files on
disk, not env vars). Its exact accepted value is not on the settings page;
confirm against code.claude.com/docs/en/env-vars before adding it to an env
block.

What is NOT changing
permissions.deny -- untouched. Deny rules are always respected, in or out
of the sandbox (rm -rf, sudo, git push --force, credential globs all still
enforced).

The hooks -- untouched. pre-security.sh is now the primary defense for
in-project secret files; pre-commit-validate.sh and pre-code-no-emoji.sh
still fire. The sandbox does not bypass hooks (hooks run in the permission
layer, before the sandbox).

The existing Bash(...) allow list -- kept. With the sandbox it is no longer
the primary boundary, but it is still the fallback-ergonomics list for
excluded commands and for the case where the sandbox is unavailable. Not
worth deleting.

.devcontainer/*/devcontainer.json -- no edits. Base images stay; install.sh
-> packages.sh already runs in postCreateCommand and will pick up socat
automatically.

claude-code/CLAUDE.md -- no edits. Deny-list semantics documented there are
unchanged.

Verification
After editing settings.json, restart Claude Code (settings reload on
startup), then:

1. /sandbox -> Dependencies tab: macOS shows Seatbelt + ripgrep ready;
   seccomp filter shows missing (expected -- Decision 1). Linux container
   shows bubblewrap + socat available; seccomp filter missing (expected).
2. /sandbox -> Config tab: confirm the merged sandbox block shows
   enabled: true, autoAllowBashIfSandboxed: true, failIfUnavailable: true,
   the denyRead list, and excludedCommands: ["obsidian *"].
3. Prompt-elimination: have Claude run a python3 here-doc and a piped
   command -- expect NO permission prompt.
4. Credential blocking: have Claude run cat ~/.ssh/id_rsa and
   cat ~/.aws/credentials inside the sandbox -- expect an OS
   permission/filesystem error, not a successful read.
5. Known-gap check: put a dummy fake-secret.pem in a test project dir,
   cat it -- expect it to succeed under the sandbox but be intercepted by
   pre-security.sh.
6. obsidian CLI (host only): temporarily empty excludedCommands, restart,
   run an obsidian command -- observe whether it breaks (socket error).
   Restore excludedCommands, restart, confirm it works and that
   Bash(obsidian:*) keeps it prompt-free.
7. Network gate: curl https://github.com succeeds; curl https://example.com
   prompts for domain approval.
8. Regression: a denied command (rm -rf something trivial) is still
   blocked; the commit and emoji hooks still fire.

Rollout order
1. Validate on macOS host first (zero install -- Seatbelt is built in).
2. make lint + make test-packages locally before committing.
3. Commit the settings.json, packages.sh, and this doc as one feat() commit.
4. Rebuild the ubuntu-zsh (or debian-bash) devcontainer and re-run
   verification steps 1-8 inside it. Focus on dependency installation,
   prompt-elimination, and the network proxy behavior.
5. unattended devcontainer rebuild can come later; it has its own
   agentic-harness postCreate steps that need separate verification.

References
Configure permissions: https://code.claude.com/docs/en/permissions
Configure the sandboxed Bash tool: https://code.claude.com/docs/en/sandboxing
Settings reference (sandbox keys): https://code.claude.com/docs/en/settings


# Note: This all started with this conversation in a different claude session:

❯ I keep getting prompted for permission with messages like " Contains shell syntax (string) that cannot be statically analyzed" or "IFS blah". How do I prevent this? Do I need to
  add some CLAUDE.md guidance to limit your shell syntax to stuff that my allow lists will support properly?

⏺ Yes, CLAUDE.md guidance is the right lever — and it works better than tweaking allow lists, which can't help here. Those prompts fire when a command can't be decomposed into a clean
   program + args form, so there's no stable prefix for an allow rule to match. You can't whitelist "all here-docs."

  Effective CLAUDE.md guidance would be a "Bash hygiene" section telling me to:

  - Prefer built-in tools over Bash. Read, Grep, Glob, Edit never prompt. Most of what triggered this in our session (vault scans, finding malformed lines) could have been Grep/Glob —
   but note this vault disables them, so that exception works against you here.
  - Avoid here-documents. Instead of python3 - <<'EOF' ... EOF, write the script to a file with the Write tool, then run python3 /tmp/script.py — a plain, analyzable invocation.
  - Avoid for/while loops, pipes, &&/|| chains, command substitution $(...), and redirections like 2>/dev/null in commands meant to run unattended. Each makes a command un-analyzable.
  - One command, one purpose. Run separate simple commands instead of chaining; simple commands match allow rules.

  A concrete block you could paste:

  ## Bash command hygiene
  - Prefer built-in tools (Read/Grep/Glob/Edit) over Bash where possible.
  - Do not use here-documents. Write scripts to a file, then run them as a plain command.
  - Avoid loops, pipes, &&/||, command substitution, and redirections in Bash commands.
  - Keep each Bash call a single simple `program args` invocation so it stays statically analyzable.

  Caveat: this reduces prompts but won't eliminate them — some tasks genuinely need a pipe or substitution, and those will still ask. For the vault-scanning work specifically, the
  cleanest fix is the file-based script pattern (Write a .py, then python3 file.py), since that one analyzable invocation can also be allow-listed.

  The other option, if you'd rather not constrain command style, is changing the session permission mode to one that doesn't gate Bash — but that relaxes the safety check broadly, so
  the CLAUDE.md approach is the more targeted choice.

❯ /btw I keep getting prompted for permission with messages like " Contains shell syntax (string) that cannot be statically analyzed" or "IFS blah". How do I prevent this? Do I need
to add some CLAUDE.md guidance to limit your shell syntax to stuff that my allow lists will support properly?
  ⎿  Branched conversation "btw: I keep getting prompted for permission with messages like " Contains shell…". You are now in the new branch (session
     38402b70-4c56-4786-8d50-0566f9bfc5a9). Use /resume 01ca696d-91d8-4a7b-ae4b-781379b64c2f to return to the original, or run claude -r 01ca696d-91d8-4a7b-ae4b-781379b64c2f in a new
     terminal.

❯ Let's add this to the CLAUDE.md in this vault.

  Read 1 file (ctrl+o to expand)
  ⎿  Interrupted · What should Claude do instead?

❯ Actually talk to me about the pros/cons here. In particular I like to keep things consistent between my dev container, cloud cone instances, and my host-level Claude Code
  instances. I'm obviously aware that the host stuff is much more dangerous from a security perspective, since that session typically has many more permissions that could be
  problematic from a security perspective. I would like to keep things consistent between the two. Why does Claude Code like to use this crazy syntax where we customize the bash
  calls so much that they can't be security-grep'd?

⏺ Good instinct to pause on this. There are a couple of things tangled together, and pulling them apart changes the answer.

  Why the "crazy syntax" happens

  It isn't Claude Code choosing it — it's me. When you give me a task like "find every malformed task line in the vault," the most direct expression is a Python here-doc or a for loop
   with a pipe. I reach for the most expressive single command that finishes the job, because that's usually the fewest tool calls. I don't get a signal that it triggered a permission
   prompt on your end unless you tell me — so without guidance, I'll keep doing it. That's exactly the gap CLAUDE.md guidance is meant to close: it's the feedback channel.

  The harness can't fix this after the fact. Here's the mechanism, because it explains everything else:

  The permission analyzer tries to decompose your command into program + arguments so it can match it against an allowlist prefix like Bash(python3:*). It can do that for python3
  scripts/scan.py. It cannot do it for python3 - <<'EOF' ... EOF, a pipeline, $(...), or anything touching IFS. Those constructs change shell parsing semantics — the effective
  argument vector isn't known until runtime. The "IFS" warning specifically is the analyzer noticing word-splitting can be redefined, which means it can't trust its own decomposition.
   So it does the safe thing: gives up on static proof and asks you.

  That last part is the key reframe: the prompt is the system working correctly. When it can't prove a command is on your allowlist, it fails safe to a human. Your allowlist was never
   the security boundary by itself — the allowlist plus the prompt fallback is.

  Where this collides with your consistency goal

  You want one mental model across dev container, cloud, and host. But those environments have genuinely different blast radii, and that's not a bug to paper over:

  - Container / cloud cone: sandboxed. Complex bash is fine — if it goes wrong, the damage is contained.
  - Host: broad permissions, real damage possible. The prompt-on-unanalyzable behavior is doing the job the sandbox does elsewhere.

  So suppressing host prompts by constraining my command style removes friction without adding safety. The thing that's dangerous on the host is the permission grant, not the syntax.
  A greppable command and an ungreppable one are equally capable of rm -rf — one just lets you audit it more easily after the fact.

  This is the crux: CLAUDE.md is the wrong layer for a security control. It's advisory text I read and mostly follow. It is not enforcement. If you treat "keep commands analyzable" as
   your security boundary, you have a boundary the model can drift past under a complex task — and it will, occasionally. Your real boundary is settings.json permissions, the
  pre-security.sh hook, and sandboxing. Those are what you should keep identical across environments, and from your global config you already do.

  Pros and cons of adding the guidance anyway

  It's still worth adding — just for the right reasons.

  Pros:
  - Fewer host prompts; less interrupt-driven workflow.
  - Genuinely better auditability. python3 scripts/scan.py can be read, diffed, version-controlled, and allowlisted. A here-doc can't. That's a real practice win, independent of
  prompts.
  - It composes with your allowlist: once commands decompose cleanly, Bash(python3:*) actually matches them. Today it often can't, because the analyzer chokes on the here-doc before
  it ever sees python3.
  - Travels with the repo; consistent everywhere.

  Cons:
  - It's soft. You'll still get occasional prompts on the host, and you cannot lean on it as a guarantee.
  - It taxes efficiency in the safe environments — you'd have me write scratch scripts to files in the sandbox where it doesn't matter, costing extra tool calls and leaving files to
  clean up.
  - It can lull you into thinking the host got safer. It didn't; it got quieter.

  How I'd actually frame it

  If you value the single mental model — and it sounds like you do — the honest move is to standardize on the host's stricter style everywhere and accept the mild inefficiency in the
  sandbox. That's a legitimate trade. But word the CLAUDE.md section as what it is: a style and auditability convention, not a safety mechanism. Something like "prefer statically
  analyzable commands: write scripts to files rather than here-docs, avoid pipelines/substitution/loops in a single Bash call." That reduces prompts, improves auditability, and reads
  honestly.

  And keep your actual security consistency where it belongs: in settings.json + hooks, identical across all three environments, with the host simply running in a less permissive mode
   than the sandbox. The prompts you still get on the host after all this? Those are a feature. An environment with that much blast radius should make you click "yes" sometimes.

  Want me to add the section to this vault's CLAUDE.md with that framing — explicitly labeled as a style/auditability convention rather than a security control?

✻ Cogitated for 1m 13s

❯ Not yet. First, you brought something up that I thought was interesting. CLAUDE code clearly isn't getting the feedback that the security hook is, and the settings.json permissions
   are causing prompts. How do we get that feedback back into CLAUDE code directly, on every prompt, so that it knows that it should be disambiguating or splitting calls up so that
  they can be analyzed properly by the security hooks?

⏺ Right — you've identified the actual gap. Let me lay out what's happening and the mechanism that closes it.

  The feedback asymmetry today

  When a Bash call hits the analyzer, three things can happen, and only one of them teaches me anything:

  - Approved at the prompt — the command runs, I get its output, and I learn nothing. The "cannot be statically analyzed / IFS" reasoning was shown to you, in the permission UI. It
  never enters my context. So I cheerfully write the next here-doc.
  - Denied at the prompt — I get a tool error ("user declined"). That's feedback, but blunt: it tells me you said no, not why, and not what to do instead.
  - Hook blocks it — this is the one channel where structured text reliably flows back to me.

  So your instinct is exactly right. The analyzer's reasoning is human-facing by design. To get it into my context on every call, you have to manufacture the channel — and hooks are
  that channel.

  The mechanism: a PreToolUse hook that blocks and explains

  A PreToolUse hook runs before the Bash call executes. The key behavior: if the hook exits with code 2, the call is blocked and the hook's stderr is delivered to me as the model.
  That stderr becomes, effectively, my next instruction. I then retry — and because the message can be specific, I retry correctly.

  So the design is a hook on Bash that:

  1. Inspects the command string for the un-analyzable constructs — here-docs (<<), pipes (|), command substitution ($(...) / backticks), &&/|| chains, IFS=, leading for/while.
  2. On a match, exits 2 with a stderr message that is actionable, not just a complaint:

  ▎ "This command uses a here-doc, which the permission analyzer can't decompose. Write the script to a file (e.g. scripts/scan.py) and run it as python3 scripts/scan.py — a plain
  invocation that matches Bash(python3:*)."

  That message lands in my context, I correct, and within a few cycles in a session I'm primed. This is everything CLAUDE.md guidance is, except: deterministic, fires on every call
  instead of being read once, and enforced rather than advisory.

  Why this beats CLAUDE.md for your goal — and why you still want both

  CLAUDE.md is read once at session start and competes with everything else in context; under a complex task I can drift past it. A hook fires every single call and doesn't drift. For
   "feedback on every prompt," the hook is the literal answer to your question.

  But they're complementary, not either/or:

  - CLAUDE.md makes me write analyzable commands on the first try, so the hook rarely needs to fire.
  - The hook catches the misses and teaches in the moment.

  Best case: CLAUDE.md keeps the hook quiet; the hook makes CLAUDE.md enforceable.

  The consistency angle — this is where it gets nice for you

  You wanted one artifact across dev container, cloud, and host. A hook gives you that cleanly: deploy the same hook script everywhere, and have it key its behavior off an environment
   variable (CLAUDE_ENV=host vs sandbox, or detect the container).

  - Host: exit 2, block, teach. You get analyzable commands and far fewer raw permission prompts.
  - Sandbox / cloud: exit 0, allow. Complex bash runs freely because the blast radius is contained — no efficiency tax where you don't need it.

  Same file, same policy, behavior derived from environment — which is exactly the model you already use for your real security settings. The hook becomes the consistent artifact; the
   environment variable is the one thing that legitimately differs.

  Caveats worth knowing before you build it

  - Approximation, not parity. Your hook can't perfectly mirror the harness's internal analyzer — shell is genuinely hard to parse. Keep the detection conservative: match the obvious
  triggers and accept some false negatives. The goal is "nudge toward simple commands," not "exactly reproduce the analyzer."
  - It costs a round-trip. Block-then-retry means a wasted call each time it fires. That round-trip is the learning, but on the host you'll feel it until I'm primed. CLAUDE.md
  guidance shrinks how often it happens.
  - The message quality is everything. The stderr is my next instruction. "Don't use here-docs" produces a vague retry; "write to scripts/X.py and run python3 scripts/X.py" produces
  the right one. Spell out the alternative.
  - It must block to teach. A hook that returns "ask" just produces another human prompt — it doesn't reach me. The teaching only happens on the exit-2 block path.

  If you want, I can draft the hook (pre-bash-analyzability.sh), wire it into settings.json as a PreToolUse hook on Bash with the environment-variable gate, and add a short matching
  CLAUDE.md section framed as a style convention. Say the word and I'll lay it out as a plan first.

✻ Sautéed for 1m 27s

❯ Okay, I'm curious, but let's do some online research. This can't be! I can't be the only one running into this. In particular, obviously I think the analyzeability and auditability
   of the bash log is key for my agentic coding situation or for other people running into this. Is this a common scenario, and what's the best practice that you see online for
  people who have dealt with this?

⏺ Web Search("Claude Code bash "cannot be statically analyzed" permission prompt")
  ⎿  Did 1 search in 6s

⏺ Web Search("Claude Code bash command permission prompts complex shell syntax best practice")
  ⎿  Did 1 search in 8s

⏺ Fetch(https://github.com/anthropics/claude-code/issues/21503)
  ⎿  Received 307.9KB (200 OK)

⏺ Fetch(https://code.claude.com/docs/en/permissions)
  ⎿  Received 32.8KB (200 OK)

⏺ Fetch(https://blog.stackademic.com/stop-fighting-claude-codes-permission-prompts-here-s-how-the-system-actually-works-ae594e59fb13)
  ⎿  Received 1KB (307 Temporary Redirect)

⏺ Fetch(https://dev.to/yurukusa/6-claude-code-permission-traps-i-found-answering-github-issues-this-week-3ja2)
  ⎿  Received 131.8KB (200 OK)

⏺ Rich results. Let me pull the sandboxing doc too, since it turns out to be central to the answer:

⏺ Fetch(https://code.claude.com/docs/en/sandboxing)
  ⎿  Received 30.7KB (200 OK)

⏺ Did the research. Short version: you're very much not alone, the specific thing you identified is a known issue that was closed without a fix, and the best practice has shifted to a
   different layer than the one you've been fighting.

  Yes, this is common — and your feedback-loop instinct is a filed issue

  The permission-prompt friction shows up across a cluster of GitHub issues: allowed commands still prompting (#26796), Bash(command:*) rules not preventing prompts (#20449), prompts
  triggering on cd instead of the real command in compound statements (#28240), and the &&-chaining backdoor (#28784). There's a whole "6 permission traps" article. So the friction is
   well-trodden ground.

  But the sharper find: the exact thing you asked about last turn — getting prompt feedback back to the model — is issue #21503: "Permission prompts are erased from Claude's context
  after user approval." It documents precisely your problem: when you approve a prompt, the model sees only the result, never learns a prompt happened, can't debug it, and will
  cheerfully misreport "permissions work fine." It was filed with a reproduction, labeled area:core / area:security / bug / memory — and closed as "not planned," then went stale. The
  proposed fix (retain prompts in context the way tool errors are) was declined.

  So: the native feedback loop you want doesn't exist and isn't coming. You independently rediscovered a won't-fix.

  The best practice is to stop fighting the analyzer — use the sandbox

  Here's the reframe the research surfaced. You've been trying to make my commands statically analyzable so the analyzer stops prompting. The current best practice is to not depend on
   the analyzer at all — enable Claude Code's built-in Bash sandbox, which replaces per-command prompts with an OS-enforced boundary.

  How it changes the picture:

  - In auto-allow mode, sandboxed Bash commands run without any permission prompt. The gate is no longer "can this command string be decomposed" — it's "does the OS sandbox contain
  it." A here-doc, a pipe, IFS=, command substitution — none of it prompts anymore, because analyzability stopped being the question.
  - Enforcement is OS-level: Seatbelt on macOS, bubblewrap on Linux/WSL2. The docs are explicit that this "holds regardless of what the model chose to run and even if an allowed
  command does more than its name suggests" — which a string-matching allowlist cannot promise.
  - Deny rules still apply; rm -rf / and home-directory removal still circuit-break.

  This directly dissolves your consistency-vs-safety tension — and inverts it. You assumed host = more dangerous, so consistency costs you safety there. With the sandbox it's the
  opposite: the host gets safer and quieter at the same time, because a real OS boundary replaces model-judgment-plus-a-prompt.

  The consistency mechanics: set sandbox.enabled: true once in ~/.claude/settings.json (user settings) and it applies to every project, every environment. macOS host needs nothing
  installed (Seatbelt is built in); Linux/container needs bubblewrap + socat. Same settings file everywhere — the only thing that legitimately varies per environment is the boundary
  (allowWrite paths, allowedDomains), which is exactly the kind of thing that should vary by environment.

  Secondary best practice: invert the allowlist

  The docs and the "permission traps" article converge on the same pattern for anything the sandbox doesn't cover: stop maintaining a fragile allowlist of analyzable command prefixes.
   Instead — allow Bash broadly (the sandbox contains it), keep a short deny list for genuinely dangerous things, and use a PreToolUse hook for anything needing real logic. dev.to
  calls PreToolUse hooks "the universal solution"; the docs confirm a hook's exit-code-2 block fires before permission rules even evaluate.

  That hook is also the only way to manufacture the feedback loop from #21503 — exit 2, and your stderr message reaches me. But note: if you adopt the sandbox, you may not want that
  loop anymore. The prompts that were teaching-by-friction mostly stop, so there's little left to teach.

  The docs and the "permission traps" article converge on the same pattern for anything the sandbox doesn't cover: stop maintaining a fragile allowlist of analyzable command prefixes.
   Instead — allow Bash broadly (the sandbox contains it), keep a short deny list for genuinely dangerous things, and use a PreToolUse hook for anything needing real logic. dev.to
  calls PreToolUse hooks "the universal solution"; the docs confirm a hook's exit-code-2 block fires before permission rules even evaluate.

  That hook is also the only way to manufacture the feedback loop from #21503 — exit 2, and your stderr message reaches me. But note: if you adopt the sandbox, you may not want that
  loop anymore. The prompts that were teaching-by-friction mostly stop, so there's little left to teach.

  On CLAUDE.md — the docs settle it

  Anthropic's own permissions doc, in the section on constraining commands, says verbatim: adding CLAUDE.md guidance "shapes what Claude tries but doesn't enforce a boundary, so pair
  it with one of the options above." So your instinct two turns ago not to over-invest in CLAUDE.md as the fix was correct. It's a style nudge, never a control.

  Two caveats specific to your setup

  1. The obsidian CLI may not survive the sandbox. It talks to a running Obsidian instance, likely over a local socket or localhost HTTP. The sandbox's seccomp filter blocks Unix
  domain sockets, and the network proxy gates domains. If obsidian breaks under the sandbox, the fix is one line — add obsidian to sandbox.excludedCommands so it runs outside the
  sandbox and falls back to the normal permission flow. Worth testing deliberately before committing to sandbox-everywhere.
  2. The sandbox's default read policy still allows ~/.ssh and ~/.aws/credentials. It only restricts writes by default. Your global settings already deny-list those via Read() globs,
  and the docs say Read deny rules merge into the sandbox boundary — but confirm that, or add explicit sandbox.filesystem.denyRead entries.

  Bottom line

  - Common: yes. Your feedback-loop problem specifically: known, issue #21503, closed not-planned.
  - The fix isn't making my commands prettier for the analyzer — it's moving the boundary from the analyzer to the OS sandbox.
  - That gives you the one-config-everywhere consistency you want, and makes the host safer rather than forcing a trade.
  - Keep a PreToolUse hook for the residue; treat CLAUDE.md as style only.

  If you want, next step I can lay out as a plan: a sandbox block for your user settings.json, a test of the obsidian CLI under /sandbox, and a slim PreToolUse hook — versus the
  CLAUDE.md-only route we started with. The sandbox route is more setup but it's the one the research actually endorses.

  Sources:
  - Configure permissions - Claude Code Docs
  - Configure the sandboxed Bash tool - Claude Code Docs
  - Issue #21503 - Permission prompts erased from Claude's context after approval
  - Issue #26796 - Bash tool prompts despite auto-approve settings
  - Issue #20449 - Bash(command:*) allow rules don't prevent prompts
  - Issue #28240 - Permission prompt triggers on cd in compound statements
  - Issue #28784 - Bash(cd:*) && chaining backdoor
  - 6 Claude Code Permission Traps - DEV Community