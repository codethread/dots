# REPL usage for strands

Use the REPL when the CLI becomes awkward: batch creation, symbolic references, richer queries, config reloads, or exploratory graph inspection.

## Start a connected REPL

```sh
strand weaver repl
```

For a disposable world:

```sh
strand --config-dir "$world" weaver repl
```

For one-shot forms:

```sh
printf '(ready)\n' | strand weaver repl --stdin
```

## Common helpers

```clojure
(init!)
(strand! "Title" {:owner "agent"})
(update! id {:active false})
(strand id)
(strands)
(ready)
(defquery! 'mine '[:= [:attr :owner] "agent"])
(strands 'mine)
```

## Creating a small DAG

The CLI is fine for one or two edges. For full DAGs, prefer REPL data so symbolic names are visible.

Current public REPL helpers may not expose DB batch creation directly. If the project exposes a batch helper, use that. Otherwise create strands and wire edges in a single form:

```clojure
(let [config (:id (strand! "Remove format from config model" {:area "config" :kind "cleanup"}))
      cli    (:id (strand! "Make CLI output JSON-only" {:area "cli" :kind "cleanup"}))
      docs   (:id (strand! "Update docs/init to make use! config idiomatic" {:area "docs" :kind "feature"}))
      check  (:id (strand! "Validate tests and smoke" {:area "validation" :kind "test"}))]
  (update! docs {:edges [{:type "depends-on" :to config}
                         {:type "depends-on" :to cli}]})
  (update! check {:edges [{:type "depends-on" :to docs}
                          {:type "depends-on" :to config}
                          {:type "depends-on" :to cli}]})
  {:config config :cli cli :docs docs :check check})
```

## Batch creation pattern when available

If a weaver/repl helper exposes batch creation over `skein.db/add-strand-batch!`, prefer a data shape like:

```clojure
(batch!
 [{:ref 'config
   :title "Remove format from config model"
   :attributes {:area "config" :kind "cleanup"}}
  {:ref 'cli
   :title "Make CLI output JSON-only"
   :attributes {:area "cli" :kind "cleanup"}}
  {:ref 'docs
   :title "Update docs/init to make use! config idiomatic"
   :attributes {:area "docs" :kind "feature"}
   :edges [{:type "depends-on" :to 'config}
           {:type "depends-on" :to 'cli}]}
  {:ref 'check
   :title "Validate tests and smoke"
   :attributes {:area "validation" :kind "test"}
   :edges [{:type "depends-on" :to 'docs}]}])
```

Symbolic refs avoid manually threading generated ids and make the dependency graph easier to review.

## Hot-reload config

If the world uses `skein.libs.alpha` config, hot-reload selected config-dir `init.clj` with:

```clojure
(require '[skein.libs.alpha :as libs])
(libs/reload!)
```

## Constraints

- Confirm your editor/REPL is connected to the weaver nREPL, not an unrelated project REPL, before evaluating config that should affect the weaver.
- Do not use raw DB functions from REPL unless the user accepts lower-level compatibility risk.
- Prefer weaver/repl helper APIs for normal work.
