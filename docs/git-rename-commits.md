# Renaming Git Commits

## The most recent commit

```bash
git commit --amend -m "new message"
```

If you also want to edit the body, just run `git commit --amend` (no `-m`) and your editor opens.

---

## Older commits — interactive rebase

This is the standard tool. It lets you rename, reorder, squash, or drop any commit.

```bash
# Replace N with how many commits back you want to reach
git rebase -i HEAD~N

# Or from a specific commit (exclusive — the commit itself is NOT included)
git rebase -i <hash>^
```

In the editor that opens, you'll see a list like:

```
pick a1b2c3d feat: initial Spicebar waybar configuration
pick d4e5f6a refactor: reorganize directory structure
pick 7b8c9d0 fix: restore style.css
```

Change `pick` to `reword` (or just `r`) on the lines you want to rename:

```
reword a1b2c3d feat: initial Spicebar waybar configuration
reword d4e5f6a refactor: reorganize directory structure
pick   7b8c9d0 fix: restore style.css
```

Save and close. Git will stop at each `reword` commit and open a new editor window where you type the new message.

---

## This repo's garbled commits

Several early commits in this repo have ANSI escape codes in their messages (caused by piping colored `git show` output directly into `git commit -m`). Run this to fix them all at once:

```bash
git rebase -i bc89b848^
```

In the editor, change `pick` to `reword` on these lines:

| Short hash | Current (garbled) | Correct message |
|---|---|---|
| `bc89b84` | `First Version` | `chore: initial commit` |
| `3776672` | `First Version` | `feat: initial Spicebar waybar configuration` |
| `baf50f9` | `Alternative Version` | `feat: add Spicebar alternative layout` |
| `7e95b07` | `[1mSTDIN[0m ...` | `docs: add calendar spec` |
| `77b34b1` | `[1mSTDIN[0m ...` | `feat: calendar on clock right-click via khal + vdirsyncer` |
| `279aa97` | `[1mSTDIN[0m ...` | `refactor: reorganize directory structure` |

After the rebase, push with force (required after rewriting history):

```bash
git push --force-with-lease origin main
```

`--force-with-lease` is safer than `--force`: it fails if someone else pushed since your last fetch.

---

## Bulk rename with filter-repo (modern alternative)

`git filter-repo` is the modern replacement for the deprecated `git filter-branch`. Install it first:

```bash
sudo pacman -S git-filter-repo
```

Rename by matching message content:

```bash
git filter-repo --message-callback '
    if b"STDIN" in message:
        return message.split(b"refactor:")[1].strip() if b"refactor:" in message else message
    return message
'
```

Or map exact commits by hash in a Python callback:

```bash
git filter-repo --message-callback '
import re, os
h = os.environ.get("GIT_COMMIT", b"")
mapping = {
    b"279aa972": b"refactor: reorganize directory structure",
    b"77b34b10": b"feat: calendar on clock right-click via khal + vdirsyncer",
}
for prefix, new_msg in mapping.items():
    if h.startswith(prefix):
        return new_msg
return message
'
```

---

## Why commits get garbled

The commits in this repo were created by piping the output of a colored command into `git commit -m`:

```bash
# This causes ANSI codes to leak into the commit message:
git commit -m "$(some-command-with-color)"
```

The fix: always pass plain text to `-m`, or use a heredoc:

```bash
git commit -m "$(cat <<'EOF'
feat: my feature
EOF
)"
```
