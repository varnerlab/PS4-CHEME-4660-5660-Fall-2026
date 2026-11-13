"""Build and test the PS4 reference-solution ZIP from a committed tree.

Run from the repository root: python3 instructor/build_solution_release.py [--ref REF]

The build starts from the Git source archive of REF (default HEAD), which holds
the student files. It replaces the four task files with the tracked solution
under solution/, renames the assignment README to ASSIGNMENT.md, and makes
solution/README.md the archive's guide. Both tracks must pass every public
check, and every number in the worked answers and the guide must appear in the
checker's report or follow from two report numbers. The ZIP is then extracted
to a new path containing spaces and both tracks are run again from it.

Writes dist/solution-release/CHEME-5660-PS4-Solution-2026.1.zip, its SHA256,
and both checker outputs. This does not commit, push a tag, or publish a
GitHub release.
"""

import argparse
import hashlib
import io
import re
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

from build_release import RELEASE_FILES

ROOT = Path(__file__).resolve().parent.parent
ARCHIVE_NAME = "CHEME-5660-PS4-Solution-2026.1"
OUTPUT = ROOT / "dist" / "solution-release"
TRACKS = (("standard", "Standard", 24), ("advanced", "Advanced", 40))
SOLUTION_FILES = {
    "README.md": "solution/README.md",
    "src/Standard.jl": "solution/src/Standard.jl",
    "src/Advanced.jl": "solution/src/Advanced.jl",
    "responses/Standard.md": "solution/responses/Standard.md",
    "responses/Advanced.md": "solution/responses/Advanced.md",
}
REPORTS = ("benchmarks.csv", "drop-worst.csv", "groups.csv", "outcomes.csv",
           "sides.csv", "summary.csv", "worst-trades.csv", "Report.md")

# Differences the answers state, in percentage points: each is |a - b| of two report numbers -
DIFFERENCES = {
    "2.3": ("67.2%", "64.9%"),   # market POP, short strangle to protected strangle
    "3.2": ("64.9%", "61.7%"),   # market POP, protected strangle to iron condor
    "0.5": ("16.4%", "15.9%"),   # capital, short strangle to protected strangle
    "10.0": ("16.4%", "6.4%"),   # capital, protected strangle to iron condor
}
# Products the answers state: each is twelve times one report number, rounded to a whole percent -
TIMES_TWELVE = {
    "-77%": "-6.4%",    # short strangle, all trades
    "+18%": "+1.5%",    # short strangle, without the worst two trades
    "55%": "+4.6%",     # the stock itself
    "124%": "+10.3%",   # put credit spread (Advanced)
}
# Percentages that are not results: the 1% stock rise of the exposure column -
SETTINGS = {"1%"}
NUMBER = re.compile(r"[+-]?\d+\.\d+%?|[+-]?\d+%")


def git(*arguments):
    """Return the bytes Git prints for one command."""
    return subprocess.check_output(["git", *arguments], cwd=ROOT)


def run_julia(folder, *arguments):
    """Run Julia in the archive's environment and keep diagnostics for a failure."""
    result = subprocess.run(
        ["julia", "--project=.", "--startup-file=no", *arguments],
        cwd=folder, capture_output=True, text=True, timeout=3600,
    )
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout + result.stderr


def run_checker(folder, track, total):
    """Run one track with the student command and require a complete, passing report."""
    (folder / "TRACK.txt").write_text(track + "\n")
    output = run_julia(folder, "check_submission.jl")
    for expected in (
        f"Track: {track}",
        f"Public tests: {total}/{total} passed",
        "Docstrings: All required functions have docstrings.",
        "All three answer blocks contain text without TODO.",
        "Local rubric feedback: pending completion review",
    ):
        if expected not in output:
            raise RuntimeError(f"{track} checker did not report: {expected}\n{output[-6000:]}")
    if "UNAVAILABLE" in output + (folder / "results" / "Report.md").read_text():
        raise RuntimeError(f"{track} report has unavailable calculations\n{output[-6000:]}")
    written = sorted(path.name for path in (folder / "results").iterdir())
    if written != sorted(REPORTS):
        raise RuntimeError(f"{track} wrote unexpected results: {written}")
    return output


def numbers(text):
    """Return every percentage and every decimal number in text, with a plain minus sign."""
    return set(NUMBER.findall(text.replace("−", "-")))


def check_numbers(name, text, report):
    """Require each number in text to be a report number, or to follow from report numbers."""
    reported = numbers(report)
    unsigned = {value.lstrip("+-") for value in reported}
    for value in sorted(numbers(text)):
        if value in SETTINGS:
            continue
        if value in DIFFERENCES:
            first, second = DIFFERENCES[value]
            if first not in reported or second not in reported:
                raise RuntimeError(f"{name}: the report lacks {first} or {second}")
            if f"{abs(float(first[:-1]) - float(second[:-1])):.1f}" != value:
                raise RuntimeError(f"{name}: {first} and {second} do not differ by {value}")
        elif value in TIMES_TWELVE:
            source = TIMES_TWELVE[value]
            if source not in reported:
                raise RuntimeError(f"{name}: the report lacks {source}")
            if f"{abs(12*float(source[:-1])):.0f}%" != value.lstrip("+-"):
                raise RuntimeError(f"{name}: twelve times {source} is not {value}")
        elif value[0] in "+-":
            if value not in reported:
                raise RuntimeError(f"{name} cites {value}, which is not in the report")
        elif value not in unsigned:
            raise RuntimeError(f"{name} cites {value}, which is not in the report")


def answers(text):
    """Return the text inside the three answer blocks."""
    return "\n".join(re.findall(r"<!-- answer-\d:start -->(.*?)<!-- answer-\d:end -->", text, re.S))


def questions(text):
    """Return the response text from Question 1 on, with the answer blocks emptied."""
    text = text[text.index("\n## 1."):]
    return re.sub(r"(<!-- answer-(\d):start -->).*?(<!-- answer-\2:end -->)", r"\1\3", text, flags=re.S)


def docstrings(text):
    """Return every docstring in a Julia source file, in order."""
    return re.findall(r'"""(.*?)"""', text, re.S)


def check_documents(folder, original):
    """Check links, math markup, answers, questions, docstrings, and placeholders."""
    for path in [folder / "README.md", *sorted((folder / "responses").glob("*.md"))]:
        text = path.read_text()
        if "TODO" in text:
            raise RuntimeError(f"{path.name} still contains TODO")
        for marker in ("$", "\\(", "\\[", "\\frac", "\\mathbf"):
            if marker in text:
                raise RuntimeError(f"{path.name} contains math markup: {marker}")
        for link in re.findall(r"\]\(([^)]+)\)", text):
            if "://" not in link and not link.startswith("#"):
                if not (path.parent / link.split("#")[0]).exists():
                    raise RuntimeError(f"Broken local link in {path.name}: {link}")
    for _, name, _ in TRACKS:
        response = (folder / "responses" / f"{name}.md").read_text()
        if questions(response) != questions(original[f"responses/{name}.md"].decode()):
            raise RuntimeError(f"The {name} questions differ from the assignment")
        for index in range(1, 4):
            start, end = f"<!-- answer-{index}:start -->", f"<!-- answer-{index}:end -->"
            if response.count(start) != 1 or response.count(end) != 1:
                raise RuntimeError(f"{name} answer {index} markers are missing or repeated")
            if not response.split(start)[1].split(end)[0].strip():
                raise RuntimeError(f"{name} answer {index} is empty")
        code = (folder / "src" / f"{name}.jl").read_text()
        if docstrings(code) != docstrings(original[f"src/{name}.jl"].decode()):
            raise RuntimeError(f"{name} docstrings differ from the assignment")
        if 'error("Complete ' in code or "TODO" in code:
            raise RuntimeError(f"{name} still contains a starter placeholder")


def check_reference_copies():
    """In the private build repository, the instructor reference must equal the solution."""
    for _, name, _ in TRACKS:
        reference = ROOT / "instructor" / "reference" / f"{name}.jl"
        if reference.exists() and reference.read_bytes() != (ROOT / "solution" / "src" / f"{name}.jl").read_bytes():
            raise RuntimeError(f"instructor/reference/{name}.jl differs from solution/src/{name}.jl")


def write_archive(folder, destination):
    """Write the folder under one archive root with fixed timestamps and permissions."""
    with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(folder.rglob("*")):
            if path.is_file():
                info = zipfile.ZipInfo(f"{ARCHIVE_NAME}/{path.relative_to(folder).as_posix()}",
                                       date_time=(2026, 11, 12, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o100644 << 16
                archive.writestr(info, path.read_bytes())


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--ref", default="HEAD", help="Committed tree to build from")
    arguments = parser.parse_args()
    commit = git("rev-parse", f"{arguments.ref}^{{commit}}").decode().strip()
    print(f"Building from commit {commit}", flush=True)
    check_reference_copies()

    OUTPUT.mkdir(parents=True, exist_ok=True)
    student_bytes = git("archive", "--format=zip", commit)
    with tempfile.TemporaryDirectory(prefix="ps4 solution build ") as temporary:
        workspace = Path(temporary)
        folder = workspace / ARCHIVE_NAME
        with zipfile.ZipFile(io.BytesIO(student_bytes)) as archive:
            original = {name: archive.read(name) for name in archive.namelist() if not name.endswith("/")}
        if not set(RELEASE_FILES) <= set(original):
            raise RuntimeError(f"Missing student files: {sorted(set(RELEASE_FILES) - set(original))}")

        # Start from the student files only; Git's settings files are not part of the assignment -
        for name in RELEASE_FILES:
            path = folder / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(original[name])
        if (folder / "TRACK.txt").read_text().strip() != "standard":
            raise RuntimeError("TRACK.txt must be standard in the committed tree")

        # Replace the task files and the opening guide with the committed solution -
        (folder / "ASSIGNMENT.md").write_bytes(original["README.md"])
        for target, source in SOLUTION_FILES.items():
            (folder / target).write_bytes(git("show", f"{commit}:{source}"))

        manifest = (folder / "Manifest.toml").read_bytes()
        run_julia(folder, "-e", "using Pkg; Pkg.instantiate()")
        if (folder / "Manifest.toml").read_bytes() != manifest:
            raise RuntimeError("Pkg.instantiate changed the recorded Manifest.toml")
        print("PASS: documented package setup; recorded versions unchanged", flush=True)

        # Run both tracks; keep each run's results for the extracted-ZIP comparison -
        saved = {}
        guide = (folder / "README.md").read_text()
        for track, name, total in TRACKS:
            output = run_checker(folder, track, total)
            (OUTPUT / f"{track}-verification.txt").write_text(output)
            report = (folder / "results" / "Report.md").read_text()
            response = (folder / "responses" / f"{name}.md").read_text()
            check_numbers(f"responses/{name}.md", answers(response), report)
            check_numbers("README.md", guide[guide.index("## What the results show"):], report)
            saved[track] = {path.name: path.read_bytes() for path in (folder / "results").iterdir()}
            print(f"PASS: {track}, {total}/{total} checks, completed answers, and cited numbers", flush=True)

        # Remove generated files and restore the starting track before packaging -
        shutil.rmtree(folder / "results")
        (folder / "MANIFEST.txt").unlink()
        (folder / "TRACK.txt").write_bytes(original["TRACK.txt"])
        check_documents(folder, original)

        replaced = set(SOLUTION_FILES)
        for name in RELEASE_FILES:
            if name not in replaced and (folder / name).read_bytes() != original[name]:
                raise RuntimeError(f"The checker changed a supplied file: {name}")
        files = {path.relative_to(folder).as_posix() for path in folder.rglob("*") if path.is_file()}
        if files != set(RELEASE_FILES) | {"ASSIGNMENT.md"}:
            raise RuntimeError(f"Unexpected archive contents: {sorted(files ^ (set(RELEASE_FILES) | {'ASSIGNMENT.md'}))}")
        print("PASS: unchanged questions and docstrings, local links, and file allowlist", flush=True)

        destination = OUTPUT / f"{ARCHIVE_NAME}.zip"
        write_archive(folder, destination)

        # Test the downloadable ZIP itself in a new path containing spaces -
        extracted = workspace / "fresh extraction"
        with zipfile.ZipFile(destination) as archive:
            if archive.testzip() is not None:
                raise RuntimeError("The solution ZIP failed its integrity check")
            archive.extractall(extracted)
        final = extracted / ARCHIVE_NAME
        for track, _, total in TRACKS:
            run_checker(final, track, total)
            for result_name, content in saved[track].items():
                if (final / "results" / result_name).read_bytes() != content:
                    raise RuntimeError(f"{track} {result_name} differs between runs")
        digest = hashlib.sha256(destination.read_bytes()).hexdigest()
        (OUTPUT / f"{ARCHIVE_NAME}.zip.sha256").write_text(f"{digest}  {destination.name}\n")
        print(f"SOLUTION-ARCHIVE-OK: {len(files)} files, both extracted tracks verified", flush=True)
        print(f"SHA256: {digest}", flush=True)
        print(destination, flush=True)


if __name__ == "__main__":
    main()
