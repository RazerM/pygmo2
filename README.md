pygmo
=====

[![Python CI](https://img.shields.io/github/actions/workflow/status/esa/pygmo2/ci-python.yml?branch=master&style=for-the-badge&label=Python%20CI)](https://github.com/esa/pygmo2/actions/workflows/ci-python.yml)
[![Wheel Builder](https://img.shields.io/github/actions/workflow/status/esa/pygmo2/wheel-builder.yml?branch=master&style=for-the-badge&label=Wheel%20Builder)](https://github.com/esa/pygmo2/actions/workflows/wheel-builder.yml)
<!-- [![Build Status](https://img.shields.io/travis/esa/pygmo2/master.svg?logo=travis&style=for-the-badge)](https://travis-ci.com/esa/pygmo2) -->

[![Anaconda-Server Badge](https://img.shields.io/conda/vn/conda-forge/pygmo.svg?style=for-the-badge)](https://anaconda.org/conda-forge/pygmo)
[![PyPI](https://img.shields.io/pypi/v/pygmo.svg?style=for-the-badge)](https://pypi.python.org/pypi/pygmo)

[![DOI](https://joss.theoj.org/papers/10.21105/joss.02338/status.svg)](https://doi.org/10.21105/joss.02338)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.1045337.svg)](https://doi.org/10.5281/zenodo.1045336)

pygmo is a scientific Python library for massively parallel optimization. It is built around the idea
of providing a unified interface to optimization algorithms and to optimization problems and to make their
deployment in massively parallel environments easy.

If you are using pygmo as part of your research, teaching, or other activities, we would be grateful if you could star
the repository and/or cite our work. For citation purposes, you can use the following BibTex entry, which refers
to the [pygmo paper](https://doi.org/10.21105/joss.02338) in the Journal of Open Source Software:

```bibtex
@article{Biscani2020,
  doi = {10.21105/joss.02338},
  url = {https://doi.org/10.21105/joss.02338},
  year = {2020},
  publisher = {The Open Journal},
  volume = {5},
  number = {53},
  pages = {2338},
  author = {Francesco Biscani and Dario Izzo},
  title = {A parallel global multiobjective framework for optimization: pagmo},
  journal = {Journal of Open Source Software}
}
```

The DOI of the latest version of the software is available at [this link](https://doi.org/10.5281/zenodo.1045336).

The full documentation can be found [here](https://esa.github.io/pygmo2/).

Installation
------------

The recommended installation route is via conda-forge:

```bash
conda install -c conda-forge pygmo
```

You can also install from PyPI:

```bash
pip install pygmo
```

PyPI wheels are provided for Linux `x86_64` and `aarch64`, macOS `arm64`, and
Windows `x64`. On other platforms, please use conda-forge or follow the
[source-build instructions](https://esa.github.io/pygmo2/install.html#building-with-pip).
