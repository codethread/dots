# Adding strand queries

Use named queries when users or agents need to repeatedly ask for the same subset of strands, especially from the CLI with `list --query <name>` or `ready --query <name>`.

## Knowledge

Named queries live in weaver memory for the weaver lifetime. Reload trusted config or call `defquery!` / config registration again after restart.

The CLI consumes registered query names; rich EDN query authoring belongs in config or REPL workflows.

## REPL quick path

```clojure
(defquery! 'agent-owned '[:= [:attr :owner] "agent"])
(strands 'agent-owned)
(ready 'agent-owned)
```

Then from shell:

```sh
strand list --query agent-owned
strand ready --query agent-owned
```

## Parameterized queries

Use params for reusable query shapes:

```clojure
(defquery! 'by-owner
  {:params [:owner]
   :where [:= [:attr :owner] [:param :owner]]})
```

CLI usage:

```sh
strand list --query by-owner --param owner=agent
strand ready --query by-owner --param owner=agent
```

## Config-backed queries

For queries that should come back after a weaver restart, register them from selected config-dir `config.clj` or `init.clj`.

Example `config.clj`:

```clojure
(ns user.config
  (:require [skein.weaver.api :as api]
            [skein.weaver.runtime :as runtime]))

(defn install! []
  (api/register-query @runtime/current-runtime
    'agent-owned
    [:= [:attr :owner] "agent"])
  (api/register-query @runtime/current-runtime
    'by-owner
    {:params [:owner]
     :where [:= [:attr :owner] [:param :owner]]}))
```

If `init.clj` activates this with `libs/use!`, a broken optional config load is recorded instead of killing the weaver by default.

## Decisions

### SHOULD_ADD_QUERY

- guard: query is one-off exploration
  → use ad hoc REPL query, do not persist/register
- guard: query will be reused by CLI/agents during this weaver lifetime
  → register with `defquery!`
- guard: query should survive restart/reload
  → add it to config-backed install function

## Constraints

- Do not add CLI flags for rich EDN query expressions.
- Do not store behavior in strand attributes when a named query in config is the intended reusable behavior.
- Keep query names simple and unqualified for CLI consumption.

## Validation

- [ ] REPL call returns expected strands.
- [ ] If CLI consumption is intended, `strand list --query <name>` or `strand ready --query <name>` succeeds.
- [ ] Parameterized queries fail loudly on missing/unknown params and succeed with expected params.
