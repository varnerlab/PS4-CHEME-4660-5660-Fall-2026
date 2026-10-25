"""Build a student ZIP from an explicit allowlist; never archive the repository wholesale."""
from pathlib import Path
import re
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "PS4-CHEME-4660-5660-Fall-2026"
RELEASE_FILES = [
    "README.md", "RUBRIC.md", "Project.toml", "Manifest.toml", "TRACK.txt",
    "Include.jl", "check_submission.jl", "explore.jl",
    "config/defaults.toml", "config/explore.toml",
    "src/Standard.jl", "src/Advanced.jl", "src/Support.jl", "src/Config.jl",
    "src/Trades.jl", "src/Models.jl", "reports/Options.jl", "reports/Terminal.jl",
    "test/Rubric.jl", "test/Fixtures.jl", "test/public_standard_tests.jl",
    "test/public_advanced_tests.jl", "responses/Standard.md", "responses/Advanced.md",
    "data/README.md", "data/trades.csv", "data/parameters.csv", "data/benchmark.csv",
    "docs/PS4-Mathematical-Companion.pdf", "docs/PS4-Mathematical-Companion.tex",
    "docs/figs/Fig-Straddle-Strangle.pdf", "docs/figs/Fig-Protected-Condor.pdf",
    "docs/figs/Fig-Credit-Spreads.pdf",
    "docs/style/assets/cornell-seal.pdf", "docs/Makefile", "docs/vnslides.sty",
    "docs/style/vnslides.sty", "docs/style/vnflow.sty",
]


def check_starter(root: Path) -> None:
    """Require the standard track and unfinished starter code and responses under root."""
    if (root / "TRACK.txt").read_text().strip() != "standard":
        raise ValueError("Reset TRACK.txt to standard before building the release.")
    for track, count in (("Standard", 6), ("Advanced", 10)):
        source = (root / f"src/{track}.jl").read_text()
        if len(re.findall(r'^function ', source, re.M)) != count or len(set(
            re.findall(r'error\("Complete ([A-Za-z_0-9]+):', source))) != count:
            raise ValueError(f"{track} must contain exactly {count} unfinished functions.")
        if (root / f"responses/{track}.md").read_text().count("TODO:") != 3:
            raise ValueError(f"Restore the three {track} response placeholders.")


def build_release() -> Path:
    """Validate starter state and return a reproducible student ZIP under dist/."""
    check_starter(ROOT)
    for name in RELEASE_FILES:
        path = ROOT / name
        if path.is_symlink() or not path.is_file():
            raise ValueError(f"Missing or symbolic-link release file: {name}")
        if not path.resolve().is_relative_to(ROOT.resolve()) or any(
            parent.is_symlink() for parent in path.parents if parent != ROOT.parent):
            raise ValueError(f"Unexpected release path: {name}")
    destination = ROOT / "dist" / f"{PACKAGE}-student.zip"
    destination.parent.mkdir(exist_ok=True)
    with ZipFile(destination, "w", compression=ZIP_DEFLATED) as archive:
        for name in RELEASE_FILES:
            info = ZipInfo(f"{PACKAGE}/{name}", date_time=(2026, 10, 25, 0, 0, 0))
            info.compress_type = ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, (ROOT / name).read_bytes())
    with ZipFile(destination) as archive:
        expected = {f"{PACKAGE}/{name}" for name in RELEASE_FILES}
        if set(archive.namelist()) != expected or archive.testzip() is not None:
            raise ValueError("The release archive failed its allowlist or integrity check.")
        if any(part in {"instructor", "solution", "results", ".git"}
               for name in archive.namelist() for part in Path(name).parts):
            raise ValueError("Private or generated files entered the student archive.")
    return destination


if __name__ == "__main__":
    print(build_release())
