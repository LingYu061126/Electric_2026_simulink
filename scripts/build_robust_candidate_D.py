from pathlib import Path


root = Path(__file__).resolve().parent
source = (root / "acac_robust_control_law.txt").read_text()
old = "fPfc = 20e3;"
new = "fPfc = 50e3; % Diagnostic candidate: test whether reducing fixed ripple helps light-load PF."
assert source.count(old) == 1
(root / "acac_robust_candidate_D_50kHz.txt").write_text(
    source.replace(old, new)
)
