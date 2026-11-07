# ============================================================
# 修復 model_uniform.tsv 的重複半徑（保留全部 91 欄）
# ============================================================

import numpy as np
import pandas as pd

INPUT_FILE  = "/home/zhiz8/DaMaSCUS-NewEarth-EVAP/model_uniform.tsv"
OUTPUT_FILE = "/home/zhiz8/DaMaSCUS-NewEarth-EVAP/model_fixed.tsv"

# ---------- 讀取 ----------
df = pd.read_csv(INPUT_FILE, sep="\t")
print(f"原始 shape: {df.shape}")
print(f"欄位數: {len(df.columns)}")

r = df["radius(km)"].to_numpy(dtype=float)
rho = df["pho"].to_numpy(dtype=float)

print(f"半徑範圍: {r.min():.2f} ~ {r.max():.2f} km")

# ---------- 找出重複半徑 ----------
r_unique, counts = np.unique(r, return_counts=True)
dup_radii = r_unique[counts > 1]
print(f"\n重複半徑: {dup_radii}")

# ---------- 修復半徑 ----------
r_fixed = r.copy()

for dup_r in dup_radii:
    mask = (r == dup_r)
    n = mask.sum()
    next_r = r[r > dup_r].min()

    rho_dup = rho[mask]
    is_monotonic = np.all(np.diff(rho_dup) <= 0)

    print(f"\n重複半徑 {dup_r:.2f} km:")
    print(f"  出現 {n} 次")
    print(f"  密度範圍: {rho_dup.max():.4f} → {rho_dup.min():.4f}")
    print(f"  密度單調遞減: {is_monotonic}")
    print(f"  下一個唯一半徑: {next_r:.2f} km")

    r_fixed[mask] = np.linspace(dup_r, next_r, n, endpoint=False)

    print(f"  修復為: {dup_r:.4f} ~ {r_fixed[mask].max():.4f} km")
    print(f"  間距: {(next_r - dup_r) / n:.4f} km")

# ---------- 檢查 ----------
r_u2, c2 = np.unique(r_fixed, return_counts=True)
if np.any(c2 > 1):
    print("\n警告：仍有重複半徑！")
    for ru, c in zip(r_u2, c2):
        if c > 1:
            print(f"  r = {ru:.4f} 出現 {c} 次")
else:
    print("\n半徑已全部唯一化")

# ---------- 用修復後的半徑排序，其他欄位跟著走 ----------
df["radius(km)"] = r_fixed
df = df.sort_values("radius(km)").reset_index(drop=True)

# ---------- 檢查密度單調性 ----------
rho_sorted = df["pho"].to_numpy(dtype=float)
is_monotonic = np.all(np.diff(rho_sorted) <= 0)
print(f"\n修復後密度單調遞減: {is_monotonic}")

if not is_monotonic:
    print("警告：密度不是單調遞減！")
    for i in range(len(rho_sorted) - 1):
        if rho_sorted[i+1] > rho_sorted[i]:
            print(f"  r = {df['radius(km)'][i]:.2f} → {df['radius(km)'][i+1]:.2f}, "
                  f"rho = {rho_sorted[i]:.4f} → {rho_sorted[i+1]:.4f}")

# ---------- 寫出 ----------
df.to_csv(OUTPUT_FILE, sep="\t", index=False, float_format="%.6e")
print(f"\n已輸出: {OUTPUT_FILE}")
print(f"最終 shape: {df.shape}")
print(f"半徑範圍: {df['radius(km)'].min():.2f} ~ {df['radius(km)'].max():.2f} km")