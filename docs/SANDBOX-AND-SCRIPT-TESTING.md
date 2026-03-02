# Sandbox and Script Testing

This runbook gives the minimal local testing flow before deployment.

## 1. Build once

```bash
cd /Users/prajwalghate/Documents/Work/canton/raven-contracts
dpm build --all
```

## 2. Fast path (docs-style): run scripts on IDE ledger

Use this for day-to-day validation.

```bash
cd /Users/prajwalghate/Documents/Work/canton/raven-contracts/tests

# Run one script
dpm script \
  --dar /Users/prajwalghate/Documents/Work/canton/raven-contracts/tests/.daml/dist/raven-contracts-tests-0.2.0.dar \
  --script-name Test.Main:setup \
  --ide-ledger \
  --static-time

# Run all scripts
dpm script \
  --dar /Users/prajwalghate/Documents/Work/canton/raven-contracts/tests/.daml/dist/raven-contracts-tests-0.2.0.dar \
  --all \
  --ide-ledger \
  --static-time
```

Why `--static-time` is required:

- test scripts use `passTime`
- `passTime` is not supported in wall-clock mode

## 3. Optional: run against local sandbox ledger

Start sandbox (terminal 1):

```bash
cd /Users/prajwalghate/Documents/Work/canton/raven-contracts
dpm sandbox \
  --static-time \
  --dar /Users/prajwalghate/Documents/Work/canton/raven-contracts/core/.daml/dist/raven-contracts-core-0.2.0.dar \
  --dar /Users/prajwalghate/Documents/Work/canton/raven-contracts/tests/.daml/dist/raven-contracts-tests-0.2.0.dar
```

Run script against sandbox (terminal 2):

```bash
cd /Users/prajwalghate/Documents/Work/canton/raven-contracts/tests
dpm script \
  --dar /Users/prajwalghate/Documents/Work/canton/raven-contracts/tests/.daml/dist/raven-contracts-tests-0.2.0.dar \
  --script-name Test.Main:setup \
  --ledger-host 127.0.0.1 \
  --ledger-port 6865
```

If default ports are busy, start sandbox on custom ports and use same `--ledger-port` in script.

## 4. Existing test command

```bash
cd /Users/prajwalghate/Documents/Work/canton/raven-contracts/tests
dpm test
```

This is still required for package-level regression checks.
