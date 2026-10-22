import std/[options, os, strutils, tables, tempfiles, unittest]
import ../src/shiori/[config, input, segments]
import helpers

suite "segments":
  test "tokens and durations":
    check humanTokens(999) == "999"
    check humanTokens(45_000) == "45k"
    check humanTokens(1_000_000) == "1M"
    check humanTokens(1_500_000) == "1.5M"
    check timeUntil(now + 7980, now) == "2h13m"
    check timeUntil(now + 183_600, now) == "2d3h"
    check timeUntil(now - 5, now) == "0m"

  test "hidden effort level":
    let json = fixture("full")
    check "medium" notin renderWith("[effort]\nhide_levels = [\"medium\"]", json)

  test "disabled segment":
    check renderWith("[model]\ndisabled = true", fixture("full")).find("Opus") < 0

  test "unreferenced segments are not shown":
    check renderWith("format = \"$model\"", fixture("full")) == "\e[1;36mOpus 5.5\e[0m"

  test "gauge thresholds":
    let json = """{"context_window": {"used_percentage": 95}}"""
    check renderWith("format = \"$context\"\n[context]\nformat = \"[x]($style)\"", json) == "\e[31mx\e[0m"

  test "each segment has data in full and is empty without input":
    let c = defaultConfig()
    for name in known:
      check evaluate(name, Input(), c, now).len == 0
      if name != "git_branch": check evaluate(name, parseInput(fixture("full")), c, now).len > 0

  test "cost, including zero and partially missing fields":
    let c = parseConfig("[cost]\nprecision = 3")
    let v = evaluate("cost", parseInput(fixture("full")), c, now)
    check v["usd"] == "$1.250"
    check v["duration"] == "1h02m"
    check v["added"] == "120"
    check v["removed"] == "30"
    let zero = evaluate("cost", Input(costUsd: some(0.0)), c, now)
    check zero["usd"] == "$0.000"
    check "duration" notin zero

  test "session name and vim styles":
    let c = defaultConfig()
    check evaluate("session_name", Input(sessionName: some("session")), c, now)["name"] == "session"
    for (mode, style) in [("NORMAL", "bold blue"), ("insert", "bold green"), ("REPLACE", "bold")]:
      let v = evaluate("vim_mode", Input(vimMode: some(mode)), c, now)
      check v["mode"] == mode.toUpperAscii
      check v["style"] == style

  test "directory selection, home boundary, root and truncation":
    let oldHome = getEnv("HOME")
    defer: putEnv("HOME", oldHome)
    putEnv("HOME", "/home/user")
    let c = defaultConfig()
    for (path, expected) in [("/home/user/project/", "~/project"), ("/home/user", "~"),
        ("/home/username", "/home/username"), ("/", "/"), ("/a/b/c/d", ".../b/c/d")]:
      check evaluate("directory", Input(cwd: some(path)), c, now)["path"] == expected
    check evaluate("directory", Input(currentDir: some("/first"), cwd: some("/second")), c, now)["path"] == "/first"
    check evaluate("directory", Input(currentDir: some(""), cwd: some("/second")), c, now)["path"] == "/second"
    check evaluate("directory", Input(cwd: some("/a/b/c/d")),
      parseConfig("[directory]\ntruncation_length = 0"), now)["path"] == "/a/b/c/d"

  test "git branch, detached HEAD, worktree and missing or malformed repository":
    let root = createTempDir("shiori-git-", "", here)
    defer: removeDir(root)
    let c = defaultConfig()
    createDir(root / ".git")
    let inp = Input(cwd: some(root / "repo" / "nested"))
    check evaluate("git_branch", inp, c, now).len == 0
    createDir(inp.cwd.get)
    check evaluate("git_branch", inp, c, now).len == 0
    createDir(root / "repo" / ".git")
    let head = root / "repo" / ".git" / "HEAD"
    writeFile(head, "ref: refs/heads/feature/日本語\n")
    check evaluate("git_branch", inp, c, now)["branch"] == "feature/日本語"
    check evaluate("git_branch", Input(cwd: some(root / "repo" / "deleted")), c, now).len == 0
    check evaluate("git_branch", inp, parseConfig("[git_branch]\ntruncation_length = 9"), now)["branch"] == "feature/日"
    writeFile(head, "0123456789abcdef0123456789abcdef01234567\n")
    check evaluate("git_branch", inp, c, now)["branch"] == "0123456"
    writeFile(head, "broken")
    check evaluate("git_branch", inp, c, now).len == 0
    moveDir(root / "repo" / ".git", root / "gitdir")
    writeFile(root / "repo" / ".git", "gitdir: ../gitdir\n")
    writeFile(root / "gitdir" / "HEAD", "ref: refs/heads/worktree\n")
    check evaluate("git_branch", inp, c, now)["branch"] == "worktree"
    writeFile(root / "repo" / ".git", "gitdir: " & root / "gitdir" & "\n")
    check evaluate("git_branch", inp, c, now)["branch"] == "worktree"
    writeFile(root / "repo" / ".git", "broken")
    check evaluate("git_branch", inp, c, now).len == 0
