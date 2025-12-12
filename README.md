## bundle_alphabetically

**bundle_alphabetically** is a Bundler plugin that keeps your `Gemfile` organized by alphabetizing `gem` declarations **within each group**.

- **Automatic mode**: after `bundle add` / `bundle install`, it rewrites your `Gemfile` so gems are sorted alphabetically inside each group.
- **Manual mode**: run `bundle sort_gemfile` whenever you want to clean things up (with an optional `--check` for CI).

### Installation

Install the plugin from a local checkout (see Bundler plugin docs at [Bundler plugin hooks](https://bundler.io/guides/bundler_plugins.html#4-using-bundler-hooks)):

```bash
cd /path/to/bundle_alphabetically
bundle plugin install bundle_alphabetically --path .
```

or from git:

```bash
bundle plugin install bundle_alphabetically --git /path/to/bundle_alphabetically
```

Once installed, Bundler will load `plugins.rb` and register the command and hooks.

### What it does

- Sorts `gem` entries alphabetically by name **within each context**:
  - top-level (no group)
  - each `group :name do ... end` block, separately
- Preserves:
  - non-gem lines like `source`, `ruby`, `plugin`, `path`, etc.
  - group block structure and indentation
  - comments and most surrounding blank lines
  - multi-line `gem` declarations (e.g. options hashes split across lines)

- Normalizes formatting so consecutive `gem` lines are rendered without extra blank lines between them.

It operates on the current `Bundler.default_gemfile` and rewrites it in place.

### Automatic sorting (hook)

The plugin registers an `after-install-all` hook:

- After a successful install (including `bundle add`), Bundler calls into `bundle_alphabetically`.
- The plugin sorts the `Gemfile` and prints a short message like:
  - `Gemfile gems alphabetized by bundle_alphabetically`

If the `Gemfile` is already sorted, it does nothing.

If it encounters an error parsing the `Gemfile`, it raises a `Bundler::BundlerError` and reports a message via `Bundler.ui.error`, but leaves the file unchanged.

### Manual command

The plugin adds a `bundle sort_gemfile` command via `Bundler::Plugin::API`:

```bash
bundle sort_gemfile
```

- Sorts the current `Gemfile` in place using the same rules as the hook.
- Prints `Gemfile already sorted` if no changes were needed.

For CI, you can use `--check` (or `-c`) to verify sorting without modifying the file:

```bash
bundle sort_gemfile --check
```

In `--check` mode:

- Exit successfully if the `Gemfile` is already sorted.
- Raise `Bundler::BundlerError` (non-zero exit) if changes would be required.

### Limitations

- Designed for conventional `Gemfile`s:
  - top-level `gem` calls and `group ... do` blocks
  - straightforward multi-line `gem` entries
- It does **not** attempt to fully evaluate arbitrary Ruby or heavy metaprogramming inside the `Gemfile`.

If you have an unusually dynamic `Gemfile` and hit issues, you can temporarily uninstall the plugin with:

```bash
bundler plugin uninstall bundle_alphabetically
```


