"""Analytical and failure-path tests; run inside the plot job."""

import numpy as np
import pytest
from supercooled_water_path import RD, RV, G, integrate_paths, thermodynamics


def sample():
    shape = (3, 2, 2)
    t = np.broadcast_to(np.array([270.0, 280.0, 260.0])[:, None, None], shape).copy()
    return (
        t,
        np.ones(shape),
        np.full(shape, 100.0),
        np.full(shape, 1e-4),
        np.full(shape, 2e-4),
    )


def test_cold_only_and_additivity():
    result, _ = integrate_paths(*sample())
    np.testing.assert_allclose(result["cloud"], 20)
    np.testing.assert_allclose(result["rain"], 40)
    np.testing.assert_allclose(result["total"], 60)


def test_warm_and_zero_c_are_excluded():
    args = list(sample())
    args[0][:] = 273.15
    result, _ = integrate_paths(*args)
    assert not result["total"].any()


def test_nonuniform_layers_and_deep_cold():
    t, rho, dz, qc, qr = sample()
    t[2] = 230
    dz[2] = 300
    result, _ = integrate_paths(t, rho, dz, qc, qr)
    np.testing.assert_allclose(result["cloud"], 40)
    np.testing.assert_allclose(result["cloud_below_minus40"], 30)


def test_invalid_cold_is_not_zero_or_partial_sum():
    args = list(sample())
    args[3][0, 0, 0] = np.nan
    result, _ = integrate_paths(*args)
    assert np.isnan(result["cloud"][0, 0])
    assert np.isnan(result["total"][0, 0])
    assert result["rain"][0, 0] == 40


def test_negative_qc_policy():
    args = list(sample())
    args[3][0, 0, 0] = -1e-12
    args[3][0, 0, 1] = -1e-5
    result, counts = integrate_paths(*args)
    assert result["cloud"][0, 0] == 10
    assert np.isnan(result["cloud"][0, 1])
    assert counts["cloud_small_negative_cells"] == 1


def test_invalid_thickness_or_shape():
    args = list(sample())
    args[2][0, 0, 0] = -1
    result, _ = integrate_paths(*args)
    assert np.isnan(result["total"][0, 0])
    with pytest.raises(ValueError):
        integrate_paths(*args[:-1], args[-1][:2])


def test_thermodynamic_mass_basis():
    p = np.array([80000.0])
    t = np.array([260.0])
    qv = np.array([0.01])
    theta = t / (p / 100000) ** (2 / 7)
    actual, rho = thermodynamics(theta, p, qv)
    np.testing.assert_allclose(actual, t)
    np.testing.assert_allclose(rho * (RD + qv * RV) * actual, p)
    assert G == 9.81


def test_invalid_thermodynamics():
    temperature, rho = thermodynamics(np.ones(1), np.array([-1.0]), np.zeros(1))
    assert np.isnan(temperature).all() and np.isnan(rho).all()
