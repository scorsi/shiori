{
  lib,
  buildNimPackage,
}:

buildNimPackage (finalAttrs: {
  pname = "shiori";
  # Keep in step with shiori.nimble.
  version = "0.1.0";

  # Include the README because the configuration reference is checked against every preset.
  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../shiori.nimble
      ../config.nims
      ../README.md
      ../src
      ../presets
      ../tests
    ];
  };

  lockFile = ../lock.json;
  nimFlags = [ "-d:NimblePkgVersion=${finalAttrs.version}" ];

  # The robustness rules of ADR 0002, on the installed binary: never a blank line, always exit 0.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    for input in '{}' 'garbage' '[1]'; do
      got=$(echo "$input" | HOME=$TMPDIR $out/bin/shiori)
      [ "$got" = shiori ] || { echo "unexpected output for $input: $got"; exit 1; }
    done
    got=$(echo '{"model":{"id":"m"}}' | HOME=$TMPDIR SHIORI_CONFIG=${builtins.toFile "bad.toml" "format = 1"} $out/bin/shiori 2>/dev/null)
    [ -n "$got" ] || { echo "blank line on a bad config"; exit 1; }
    for fixture in full minimal invalid pre-first-reply free-plan post-compact detached-head narrow; do
      got=$(HOME=$TMPDIR COLUMNS=40 $out/bin/shiori preview --fixture "$fixture")
      [ -n "$got" ] || { echo "blank preview for $fixture"; exit 1; }
    done
    SHIORI_CONFIG=${builtins.toFile "one-segment.toml" "format = '$model$model'"} \
      $out/bin/shiori timings < tests/fixtures/full.json > "$TMPDIR/line" 2> "$TMPDIR/timings"
    [ "$(grep -c '^segment\.' "$TMPDIR/timings")" = 1 ]
    grep -q '^segment.model:' "$TMPDIR/timings"
    [ -s "$TMPDIR/line" ]
    runHook postInstallCheck
  '';

  passthru.presets = ../presets;

  meta = {
    description = "A Starship-style status line for Claude Code";
    license = lib.licenses.mit;
    mainProgram = "shiori";
  };
})
