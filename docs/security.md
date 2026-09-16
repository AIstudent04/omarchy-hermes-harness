# Security model

## Security posture

Omarchy plugins execute unsandboxed inside the long-running `omarchy-shell` process with the logged-in user's permissions. Hermes Harness therefore keeps its command surface deliberately small and read-only.

The plugin provides visibility and launch actions. It is not an authorization boundary and must never be used to approve privileged or remote work.

## Permissions

The shipped code requires only ordinary user access:

- read plugin files;
- execute `bash`, Python 3, `jq`, `systemctl`, `hermes`, `curl`, and optionally `hermes-node` from `PATH`;
- read the user-local Hermes usage record and the `model` line from the Hermes configuration;
- query the user service manager;
- when a remote URL is configured (see "Remote status mode" below), make an outbound HTTP GET to that user-supplied host;
- open Hermes through Omarchy's bar runner.

It does not use `sudo`, `pkexec`, setuid programs, Polkit actions, root services, or package-manager hooks.

## Trust boundaries

### Plugin code

QML and the status script run with the user's authority. Install only from a reviewed repository and review updates before applying them.

### Existing telemetry record

The file `${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/agents/usage/hermes.json` is user-owned input. `hermes-safe-io` opens it with `O_NOFOLLOW`, `O_NONBLOCK`, and `O_CLOEXEC`, verifies the opened descriptor is a regular file, and rejects it above 256 KiB. The adapter then accepts it only when `jq` confirms that it is a JSON object. Values are used for display, never for command construction or authorization.

### Hermes configuration

The adapter reads only the first top-level `model` value from `${HERMES_HOME:-$HOME/.hermes}/config.yaml`. The same descriptor-safe reader rejects non-regular files and files above 64 KiB. It does not print or copy the full configuration and does not read `.env`, authentication files, OAuth state, API keys, or private keys.

### Subprocess output

`hermes-safe-io run` drains stdout through a nonblocking pipe into a bounded byte buffer, discards stderr, applies a wall-clock timeout, and kills the subprocess group on timeout or overflow. Hermes version output is limited to 4 KiB over five seconds; node status is limited to 64 KiB over 18 seconds.

### Executables on PATH

`hermes` and `hermes-node` are resolved through the shell's `PATH`. A user who replaces either executable can influence status output and launch behavior. This is consistent with ordinary desktop application trust, but it means the panel is not suitable as an integrity monitor.

### Remote status mode

Setting `hermesVpsUrl` makes the adapter fetch `<hermesVpsUrl>/api/status` over plain HTTP instead of running the local checks. The URL is user-supplied plugin settings, not attacker-controlled input; the request is a plain `GET` with no query parameters, headers, cookies, or credentials attached — nothing from this device is sent to that host beyond the request itself. The response is read through the same descriptor/byte/time-bounded `hermes-safe-io run` path as other subprocess output (`curl -fsS --max-time 3`, 65 KiB cap) and only accepted after `jq` confirms it decodes to a JSON object; an invalid or oversized response is treated as "unreachable," not partially trusted. Because the target host is a Hermes gateway the user chose to point the widget at, this does not change the "not an authorization boundary" posture: the plugin still only displays whatever that endpoint reports, never sends commands to it, and treats its output the same as any other untrusted display data.

### Federated nodes

If `hermes-node` exists, the adapter runs only its `status` subcommand. The wrapper may contact configured nodes. The plugin neither reads node YAML directly nor invokes `run` or `exec`.

## Data handling

The adapter emits a JSON object to its parent QML process. It performs no network upload, analytics, logging, or persistence of its own.

Every dynamic QML `Text` sink explicitly uses `Text.PlainText`; the bar tooltip is static. Displayed session titles and node aliases may still be visible to anyone who can see the desktop. Users should avoid publishing screenshots that contain sensitive task names or infrastructure labels.

## Failure behavior

- Missing Hermes: reports not installed.
- Missing provider record: uses an empty base object.
- Invalid provider JSON: ignores it.
- Unavailable user bus: reports an unknown or non-active gateway state.
- Missing `hermes-node`: reports it unavailable.
- Node timeout or empty response: retains the last published node summary when one exists.
- Invalid adapter JSON: the panel preserves its last known model and shows a refresh error.

This is availability-oriented fail-soft behavior for display data. It must not be interpreted as proof that a gateway, session, or node is trustworthy.

## Prohibited extensions without a new security review

Do not add any of the following as a routine plugin change:

- arbitrary shell command fields;
- secret or credential display;
- root operations;
- passwordless sudo rules;
- Polkit policy installation;
- remote command execution;
- job dispatch, retries, or asynchronous workers;
- writes to Hermes configuration or session state;
- writes under `/usr`, `/etc`, or `/usr/share/omarchy`.

Each would materially change the threat model and needs its own documented interface and review.

## Reporting security issues

Do not place secrets or exploit details in a public marketplace issue. Report concerns through the repository owner's private contact or GitHub security-advisory channel when available.
