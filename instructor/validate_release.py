"""Build and test the Git source archive without access to the private reference.

Run from any directory: python3 instructor/validate_release.py [--ref REF] [--tag TAG]
The release Action runs this with --tag before creating a draft GitHub release.
It checks the committed tree only; the working tree and instructor/reference are
not used. Run instructor/validate.jl and instructor/check_release.py locally for
the reference checks.
"""
import argparse
from pathlib import Path
import re
import subprocess
import tempfile
import zipfile
from build_release import ROOT, RELEASE_FILES, check_starter

# Students download exactly the allowlisted files plus Git's own settings files -
ALLOWED_EXTRA = {".gitattributes", ".gitignore"}
PROHIBITED = {".git", ".github", "instructor", "solution", "results", "dist", "__pycache__"}


def require(condition, message):
    """Stop the release if a required check fails."""
    if not condition:
        raise RuntimeError(message)


def git(*arguments):
    """Read the committed release tree."""
    return subprocess.check_output(["git", *arguments], cwd=ROOT, text=True).strip()


def run_julia(student, *arguments, timeout=900):
    """Run Julia in the student copy with its environment; return (exit code, output)."""
    result = subprocess.run(
        ["julia", "--startup-file=no", "--project=.", *arguments],
        cwd=student, text=True, capture_output=True, timeout=timeout,
    )
    return result.returncode, result.stdout + result.stderr


def check_contents(student, names):
    """Check the archive's file list, starter placeholders, track, README, and local links."""
    files = {name for name in names if not name.endswith("/")}
    expected = set(RELEASE_FILES)
    require(expected <= files, f"Missing student files: {sorted(expected - files)}")
    require(files <= expected | ALLOWED_EXTRA,
            f"Unexpected files in archive: {sorted(files - expected - ALLOWED_EXTRA)}")
    for name in names:
        path = Path(name)
        require(not path.is_absolute() and ".." not in path.parts, f"Invalid archive path: {name}")
        require(not PROHIBITED.intersection(path.parts), f"Instructor or generated file in archive: {name}")
    check_starter(student)

    # The README explains the task in plain language; the companion holds the math -
    readme = (student / "README.md").read_text()
    for marker in ("$", "\\(", "\\[", "\\frac", "\\mathbf"):
        require(marker not in readme, f"README.md contains math markup: {marker}")

    for markdown in student.rglob("*.md"):
        for target in re.findall(r"\]\(([^)]+)\)", markdown.read_text()):
            if target.startswith(("https:", "http:", "mailto:", "#")):
                continue
            require((markdown.parent / target.split("#")[0]).exists(),
                    f"Broken local link in {markdown.relative_to(student)}: {target}")


def check_starter_run(student, track, total):
    """The unfinished starter must report 0 checks, write a manifest, and flag every answer."""
    (student / "TRACK.txt").write_text(track + "\n")
    code, output = run_julia(student, "check_submission.jl")
    require(code == 0, f"{track} starter checker exited {code}:\n{output[-8000:]}")
    require(f"Track: {track}" in output, f"{track} starter checker reported the wrong track")
    require(f"Public tests: 0/{total} passed" in output,
            f"{track} starter did not report 0/{total}:\n{output[-8000:]}")
    require("UNAVAILABLE" in output, f"{track} starter report did not mark unfinished calculations")
    for number in (1, 2, 3):
        require(f"Question {number} still contains TODO" in output,
                f"{track} starter did not warn about question {number}")
    require("differs from the shipped copy" not in output, f"{track} starter flagged defaults.toml as edited")
    manifest = (student / "MANIFEST.txt").read_text()
    require(f"public tests passed: 0/{total}" in manifest, f"{track} manifest omitted the check count")
    require("tests ran: true" in manifest and "local solution: false" in manifest,
            f"{track} manifest recorded the wrong run state")
    require((student / "results/Report.md").exists(), f"{track} starter did not write the report")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ref", default="HEAD", help="Committed tree to check")
    parser.add_argument("--tag", help="Release tag, which must identify the same commit")
    arguments = parser.parse_args()
    if arguments.tag:
        require(git("rev-parse", f"{arguments.tag}^{{commit}}") ==
                git("rev-parse", f"{arguments.ref}^{{commit}}"), "Release tag does not match the checked commit")
        for name in ("README.md", "instructor/canvas-assignment-description.html"):
            text = git("show", f"{arguments.ref}:{name}")
            require(f"/releases/tag/{arguments.tag})" in text or f"/releases/tag/{arguments.tag}\"" in text,
                    f"{name} does not link to the release tag {arguments.tag}")

    with tempfile.TemporaryDirectory(prefix="ps4-release-") as temporary:
        directory = Path(temporary)
        archive = directory / "student.zip"
        subprocess.run(["git", "archive", "--format=zip", f"--output={archive}", arguments.ref],
                       cwd=ROOT, check=True)
        student = directory / "student"
        with zipfile.ZipFile(archive) as bundle:
            names = bundle.namelist()
            bundle.extractall(student)
        check_contents(student, names)
        print("Archive contents, starter placeholders, track, README, and local links passed.", flush=True)

        # Install the recorded environment exactly as the README instructs -
        code, output = run_julia(student, "-e", "using Pkg; Pkg.instantiate()", timeout=3600)
        require(code == 0, f"Pkg.instantiate failed:\n{output[-8000:]}")
        print("Recorded Julia environment installed.", flush=True)

        for track, total in (("standard", 24), ("advanced", 40)):
            check_starter_run(student, track, total)
            print(f"{track.title()} starter: 0/{total}, report, manifest, and answer warnings passed.", flush=True)
    print("The student source archive is ready for a draft GitHub release.")


if __name__ == "__main__":
    main()
