"""FOG NCL vis1 three-moment cloud extinction, retained as a reference algorithm.

Ported from the user's FOG/程序/三参数能见度.py without numerical changes.
This is cloud-only instantaneous extinction, not observed or hourly-minimum VIS.
"""

from __future__ import annotations

import re
from collections.abc import Iterable

import numpy as np

PI = 3.1415926  # 与参考 NCL 一致
METHOD = "NCL_vis1_three_moment_sum_extinction"


def cloud_groups(names: Iterable[str]) -> list[tuple[str, str, str]]:
    """识别无后缀单谱或完整编号谱；不根据文件名猜测，不遗漏残缺谱。"""
    names = set(names)
    q_suffixes = {
        m.group(1) for name in names if (m := re.fullmatch(r"QCLOUD(\d*)", name))
    }
    n_suffixes = {
        m.group(1)
        for name in names
        if (m := re.fullmatch(r"(?:NW|QNCLOUD)(\d*)", name))
    }
    z_suffixes = {
        m.group(1) for name in names if (m := re.fullmatch(r"NW_Z(\d*)", name))
    }
    if not q_suffixes or q_suffixes != n_suffixes or q_suffixes != z_suffixes:
        raise ValueError(
            "三参数输入不完整或谱编号不一致: "
            f"Q={sorted(q_suffixes)}, N={sorted(n_suffixes)}, Z={sorted(z_suffixes)}"
        )
    if "" in q_suffixes and len(q_suffixes) > 1:
        raise ValueError("同时存在总量与编号云滴谱，请明确输入，避免重复计数")
    suffixes = sorted(q_suffixes, key=lambda value: -1 if value == "" else int(value))
    groups = []
    for suffix in suffixes:
        number_names = {"NW" + suffix, "QNCLOUD" + suffix} & names
        if len(number_names) != 1:
            raise ValueError(
                f"谱 {suffix or '无后缀'} 的数浓度变量不唯一: {sorted(number_names)}"
            )
        number = number_names.pop()
        group = ("QCLOUD" + suffix, number, "NW_Z" + suffix)
        missing = set(group) - names
        if missing:
            raise ValueError(f"三参数输入不完整: {sorted(missing)}")
        groups.append(group)
    return groups


def extinction(
    q: np.ndarray, n: np.ndarray, z: np.ndarray, rho: np.ndarray
) -> np.ndarray:
    """同形数组输入 kg/kg、#/kg、mm6/kg、kg/m3，返回消光系数 m-1。

    采用 NCL 的掩膜、密度/数浓度保护、alpha 3..165 和 lambda 上限。
    对 AAA=1 的奇点使用未除以 (1-AAA) 的原多项式求根。
    """
    q, n, z, rho = [np.asarray(a, dtype=np.float64) for a in (q, n, z, rho)]
    if len({a.shape for a in (q, n, z, rho)}) != 1:
        raise ValueError("Q/N/Z/密度 shape 不一致")
    if not all(np.isfinite(a).all() for a in (q, n, z, rho)):
        raise ValueError("三参数输入存在缺测或非有限值")
    valid = (q >= 1e-10) & (n >= 0) & (z > 0)
    result = np.zeros(q.shape, dtype=np.float64)
    density = np.maximum(rho[valid], 1e-6)
    qc = q[valid] * density * 1e3
    nc = np.maximum(n[valid], 1.0) * density / 1e6
    zc = z[valid] * density
    aaa = zc * PI**2 * nc / (36 * qc**2)
    alpha = np.empty_like(aaa)
    singular = np.abs(1 - aaa) < 1e-8
    a = aaa[~singular]
    b = (12 - 3 * a) / (1 - a)
    c = (47 - 2 * a) / (1 - a)
    d = 60 / (1 - a)
    p = c - b**2 / 3
    v = 2 * b**3 / 27 + d - b * c / 3
    disc = (p / 3) ** 3 + (v / 2) ** 2
    root = np.empty_like(a)
    one = disc >= 0
    root[one] = (
        np.cbrt(-v[one] / 2 + np.sqrt(disc[one]))
        + np.cbrt(-v[one] / 2 - np.sqrt(disc[one]))
        - b[one] / 3
    )
    angle_arg = (-v[~one] / 2) * (-p[~one] / 3) ** -1.5
    if np.any(np.abs(angle_arg) > 1 + 1e-10):
        raise ValueError("反演 alpha 的 acos 参数超出有效域")
    angle = np.arccos(np.clip(angle_arg, -1, 1)) / 3
    roots = [
        np.sqrt(-4 * p[~one] / 3) * np.cos(angle + offset * PI / 180) - b[~one] / 3
        for offset in (0, 120, 240)
    ]
    root[~one] = np.maximum.reduce(roots)
    alpha[~singular] = root
    for index in np.flatnonzero(singular):
        a = aaa[index]
        roots = np.roots([1 - a, 12 - 3 * a, 47 - 2 * a, 60])
        real = roots.real[np.abs(roots.imag) < 1e-7]
        if real.size == 0:
            raise ValueError("三参数多项式没有可用实根")
        alpha[index] = real.max()
    alpha = np.clip(alpha, 3, 165)
    lam = np.minimum(
        np.cbrt(1e6 * (4 * PI / 3) * nc * (alpha + 2) * (alpha + 1) * alpha / qc) * 100,
        9e11,
    )
    result[valid] = 2 * PI * nc * 1e6 * alpha * (alpha + 1) / lam**2
    if not np.isfinite(result).all() or np.any(result < 0):
        raise ValueError("消光系数诊断失败")
    return result


def visibility_from_extinction(total: np.ndarray) -> np.ndarray:
    """总消光系数 m-1 转为能见度 m；无云/超过100km时统一100km。"""
    total = np.asarray(total, dtype=np.float64)
    if not np.isfinite(total).all() or np.any(total < 0):
        raise ValueError("总消光系数无效")
    visibility = np.full(total.shape, 100000.0)
    np.divide(-np.log(0.05), total, out=visibility, where=total > 0)
    return np.minimum(visibility, 100000).astype(np.float32)
