from pathlib import Path


root = Path(__file__).resolve().parent
source = (root / "acac_robust_control_law.txt").read_text()
old = "dutyUnclamped = dutyBase + currentPIOutput;"
new = """% Reduce the boost duty only around the input-voltage zero crossing.
% This addresses the observed current spike and avoids changing the
% nominal conduction interval or physical loss parameters.
zeroCrossBlend = max(0.0, 1.0 - abs(vin) / 12.0);
zeroCrossDutyCorrection = 0.08 * zeroCrossBlend;
dutyUnclamped = dutyBase + currentPIOutput - zeroCrossDutyCorrection;"""
assert source.count(old) == 1
(root / "acac_robust_candidate_B_zero_cross.txt").write_text(
    source.replace(old, new)
)
