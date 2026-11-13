"""Resolved supercooled water paths in g/m2; no model or website writes."""

from __future__ import annotations

import numpy as np

RD = 287.0
RV = 461.6
CP = 3.5 * RD
G = 9.81
FREEZE_K = 273.15
NEGATIVE_TOL = 1e-10


def integrate_paths(
    temperature_k: np.ndarray,
    dry_density: np.ndarray,
    layer_thickness: np.ndarray,
    cloud: np.ndarray,
    rain: np.ndarray,
) -> tuple[dict[str, np.ndarray], dict[str, int]]:
    """Integrate (z,y,x) kg/kg-dry fields to (y,x) g/m2 at T < 273.15 K.

    Mid-layer temperature selects the entire finite-volume layer. Any invalid
    thermodynamics, or invalid cold hydrometeor level, invalidates the column.
    Tiny negative roundoff [-1e-10,0) is clipped and counted. No upper clipping.
    The below--40 C integral is retained separately, not silently removed.
    """
    arrays = [temperature_k, dry_density, layer_thickness, cloud, rain]
    t, rho, dz, qc, qr = [np.ma.asarray(a, dtype=float).filled(np.nan) for a in arrays]
    if (
        t.ndim != 3
        or min(t.shape) < 1
        or any(a.shape != t.shape for a in (rho, dz, qc, qr))
    ):
        raise ValueError("All input fields must share a nonempty (z,y,x) shape")
    base_bad = (
        ~np.isfinite(t)
        | (t <= 0)
        | ~np.isfinite(rho)
        | (rho <= 0)
        | ~np.isfinite(dz)
        | (dz <= 0)
    )
    cold = t < FREEZE_K
    deep_cold = t < 233.15
    fields: dict[str, np.ndarray] = {}
    counts = {"invalid_thermodynamic_cells": int(base_bad.sum())}
    for name, q in (("cloud", qc), ("rain", qr)):
        invalid_q = ~np.isfinite(q) | (q < -NEGATIVE_TOL)
        bad_column = (base_bad | (cold & invalid_q)).any(axis=0)
        q_clean = np.maximum(q, 0)
        contribution = np.where(cold & ~invalid_q & ~base_bad, q_clean * rho * dz, 0)
        for suffix, selector in (("", cold), ("_below_minus40", deep_cold)):
            value = 1000 * np.sum(np.where(selector, contribution, 0), axis=0)
            value[bad_column] = np.nan
            fields[name + suffix] = value
        counts[name + "_small_negative_cells"] = int(((q < 0) & ~invalid_q).sum())
        counts[name + "_invalid_cold_cells"] = int((cold & invalid_q).sum())
    fields["total"] = fields["cloud"] + fields["rain"]
    fields["total_below_minus40"] = (
        fields["cloud_below_minus40"] + fields["rain_below_minus40"]
    )
    return fields, counts


def thermodynamics(
    theta: np.ndarray, pressure: np.ndarray, vapor: np.ndarray
) -> tuple[np.ndarray, np.ndarray]:
    """Actual T (K), dry-air density (kg/m3); qv is kg/kg dry air.

    WRF dry potential temperature: T=theta*(p/100000)^(Rd/Cp).
    Ideal gas mixture p=rho_d*Rd*T*(1+qv*Rv/Rd); avoid moist/dry bias.
    """
    if theta.shape != pressure.shape or theta.shape != vapor.shape:
        raise ValueError("Thermodynamic fields must have equal shapes")
    valid = (
        np.isfinite(theta)
        & (theta > 0)
        & np.isfinite(pressure)
        & (pressure > 0)
        & np.isfinite(vapor)
        & (vapor >= 0)
    )
    safe_p = np.where(valid, pressure, np.nan)
    temperature = theta * (safe_p / 100000.0) ** (RD / CP)
    rho_d = safe_p / (RD * temperature * (1 + vapor * RV / RD))
    return temperature, rho_d
