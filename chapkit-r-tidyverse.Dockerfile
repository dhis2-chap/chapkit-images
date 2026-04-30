# chapkit-r-tidyverse: chapkit-r + tidyverse + tidyverts forecasting
# stack (fable, tsibble, lubridate, feasts). Multi-arch (linux/amd64,
# linux/arm64).
#
# Two build targets, published as:
#
#   - chapkit-r-tidyverse     (target: runtime) chapkit-r + the modern
#                             Posit/tidy R stack, no chapkit. FROM base
#                             for scaffolded chapkit services that
#                             want tidyverse + forecasting tooling and
#                             pin their own chapkit via `uv sync`.
#   - chapkit-r-tidyverse-cli (target: bundled) runtime + a pinned
#                             chapkit from PyPI. For invoking the
#                             chapkit CLI directly via `docker run ...
#                             chapkit <subcommand>`.
#
# Pre-installed R packages (on top of chapkit-r's renv + pak):
#   tidyverse, fable, tsibble, feasts, lubridate, distributional,
#   forecast, urca, tseries, zoo, xts, readxl,
#   ranger, randomForest, xgboost, glmnet, e1071, lme4,
#   janitor, here, patchwork
#
# Most R model authors are statisticians, not Docker users — keeping
# the iteration loop tight matters more than image leanness. The
# bundle covers what an R forecasting/ML author would reach for:
#
#   - tidyverse                : the de facto data-wrangling stack
#                                (rocker/tidyverse traffic confirms
#                                this is what R users expect).
#   - fable, tsibble, feasts,  : the tidyverts forecasting trio plus
#     lubridate, distributional  the helper objects forecast outputs
#                                pass around.
#   - forecast                 : the older, widely-used Hyndman
#                                forecasting package (auto.arima,
#                                ets, ...). Distinct ecosystem from
#                                fable but ubiquitous in epi/stats
#                                code.
#   - urca, tseries            : stationarity / unit-root tests that
#                                fable::ARIMA reaches for via
#                                Suggests and that the `forecast`
#                                package imports directly.
#   - zoo, xts                 : time-series object primitives that
#                                most R ts code touches at some point.
#   - readxl                   : Excel reader (epidemiologists ship
#                                their data this way more often than
#                                they should).
#   - ranger, randomForest,    : standard ML primitives. Random
#     xgboost, glmnet, e1071,    forests (ranger modern/parallel,
#     lme4                       randomForest classic), gradient
#                                boosting, regularised regression,
#                                SVM/naive Bayes, mixed-effects
#                                models. Each individually small
#                                (~1-10 MB); together they cover
#                                what an epi/stats author would
#                                usually have installed already.
#   - janitor, here, patchwork : everyday utilities — janitor for
#                                data cleaning, here for project-
#                                relative paths, patchwork for
#                                ggplot composition.
#
# Heavier ML frameworks (tidymodels, caret, brms, rstanarm, mlr3) are
# NOT bundled — they're opinionated and add 100s of MB. Add them in a
# downstream layer or a sibling image variant if/when needed.
#
# Sits between chapkit-r (lean base) and chapkit-r-inla (R + INLA + the
# spatial/forecasting R stack). Models that need INLA should pull
# chapkit-r-inla — it inherits this image's tidyverse layer.

# Image to inherit from. Default is the published ghcr release; the
# Makefile overrides this to chapkit-r:dev when building locally.
ARG CHAPKIT_R_IMAGE=ghcr.io/dhis2-chap/chapkit-r:latest

# ---------- Stage: runtime (no chapkit) ----------
FROM ${CHAPKIT_R_IMAGE} AS runtime

# pak is already in chapkit-r and gives us binary builds where
# available (much faster than compiling from source). lubridate is a
# core tidyverse member since v2.0; listed explicitly for clarity.
RUN R -q -e "pak::pkg_install(c( \
        'tidyverse', \
        'fable', \
        'tsibble', \
        'lubridate', \
        'feasts', \
        'distributional', \
        'forecast', \
        'urca', \
        'tseries', \
        'zoo', \
        'xts', \
        'readxl', \
        'ranger', \
        'randomForest', \
        'xgboost', \
        'glmnet', \
        'e1071', \
        'lme4', \
        'janitor', \
        'here', \
        'patchwork' \
    ), upgrade = FALSE)"

# Trim help/docs/html — saves a few hundred MB (tidyverse's manuals
# alone are ~50 MB of HTML).
RUN find /usr/local/lib/R/site-library /usr/lib/R/site-library -type d \
        \( -name help -o -name doc -o -name html \) \
        -exec rm -rf {} + 2>/dev/null || true

# ---------- Stage: bundled (runtime + pinned chapkit) ----------
FROM runtime AS bundled

# Install chapkit into /app/.venv. Two install paths:
#   - default: PyPI release. Set CHAPKIT_VERSION to a PEP 440 version
#     with or without a leading 'v' (e.g. 0.24.0 or v0.24.0).
#   - override: git ref. Set CHAPKIT_GIT_REF to a branch / tag / SHA
#     (e.g. main) to install from
#     git+https://github.com/dhis2-chap/chapkit.git@<ref>. Used by the
#     nightly :dev build to track chapkit's main branch.
ARG CHAPKIT_VERSION=0.24.0
ARG CHAPKIT_GIT_REF=
RUN --mount=type=cache,target=/root/.cache/uv \
    if [ -n "${CHAPKIT_GIT_REF}" ]; then \
        uv pip install --python /app/.venv/bin/python \
            "git+https://github.com/dhis2-chap/chapkit.git@${CHAPKIT_GIT_REF}"; \
    else \
        uv pip install --python /app/.venv/bin/python \
            "chapkit==${CHAPKIT_VERSION#v}"; \
    fi

HEALTHCHECK CMD curl -fsS http://localhost:8000/health || exit 1

CMD ["chapkit", "run", ".", "--host", "0.0.0.0", "--port", "8000"]
