from pathlib import Path


root = Path(__file__).resolve().parent
source = (root / "acac_robust_control_law.txt").read_text()
old = "vdcRef = min(60.0 * max(t,0.0) / 0.15, 60.0);"
new = "vdcRef = min(56.0 * max(t,0.0) / 0.15, 56.0);"
assert source.count(old) == 1
(root / "acac_robust_candidate_E_56V_screen.txt").write_text(
    source.replace(old, new)
)
