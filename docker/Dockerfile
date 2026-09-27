# AMS Edit Book mock — toolchain image
#
# GnuCOBOL 3.2 (built from source), GixSQL 1.0.20b (embedded SQL precompiler,
# built from source because upstream ships x86_64 packages only), cobol-check,
# psql, Python + uv. The same image runs on Apple Silicon and in GitHub Actions.

FROM debian:trixie-slim

ARG GNUCOBOL_VERSION=3.2
ARG GIXSQL_VERSION=1.0.20b
ARG COBOLCHECK_VERSION=0.2.19
# cobol-check publishes no tagged release for 0.2.x; pin the commit that added the zip.
ARG COBOLCHECK_COMMIT=0921a094d68889946f5e94ad077fda99a92bf97f

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential pkg-config ca-certificates curl xz-utils unzip \
        libgmp-dev libdb-dev libncurses-dev \
        libpq-dev libspdlog-dev libfmt-dev \
        postgresql-client \
        default-jre-headless \
        python3 python3-venv \
        bison flex \
        make git ripgrep xxd bash less gdb \
    && rm -rf /var/lib/apt/lists/*

# GnuCOBOL from source: Debian's gnucobol3 package links a libxml2 that prints a
# version warning on every program exit, which pollutes job logs.
RUN curl -fsSL https://ftp.gnu.org/gnu/gnucobol/gnucobol-${GNUCOBOL_VERSION}.tar.xz | tar xJ -C /tmp \
    && cd /tmp/gnucobol-${GNUCOBOL_VERSION} \
    && ./configure --prefix=/usr/local --without-xml2 --without-json --with-db >/dev/null \
    && make -j"$(nproc)" >/dev/null && make install >/dev/null && ldconfig \
    && rm -rf /tmp/gnucobol-${GNUCOBOL_VERSION} \
    && cobc --version | head -1

# GixSQL: GCC 14 needs <cstdint> force-included; -j2 because the header-heavy
# C++ sources OOM small Docker VMs at higher parallelism.
RUN curl -fsSL https://github.com/mridoni/gixsql/releases/download/v${GIXSQL_VERSION}/gixsql-${GIXSQL_VERSION}.tar.gz | tar xz -C /tmp \
    && cd /tmp/gixsql-${GIXSQL_VERSION} \
    && CXXFLAGS="-O2 -include cstdint" ./configure --prefix=/opt/gixsql \
         --disable-mysql --disable-odbc --disable-oracle --disable-sqlite >/dev/null \
    && make -j2 >/dev/null && make install >/dev/null \
    && echo /opt/gixsql/lib > /etc/ld.so.conf.d/gixsql.conf && ldconfig \
    && rm -rf /tmp/gixsql-${GIXSQL_VERSION} \
    && /opt/gixsql/bin/gixpp --version | head -1

# cobol-check (Open Mainframe Project) — paragraph-level unit tests
RUN curl -fsSL -o /tmp/cc.zip https://raw.githubusercontent.com/openmainframeproject/cobol-check/${COBOLCHECK_COMMIT}/build/distributions/cobol-check-${COBOLCHECK_VERSION}.zip \
    && mkdir -p /opt/cobol-check && unzip -q /tmp/cc.zip -d /opt/cobol-check && rm /tmp/cc.zip \
    && ln -s /opt/cobol-check/bin/cobol-check-${COBOLCHECK_VERSION}.jar /opt/cobol-check/bin/cobol-check.jar \
    && rm -rf /opt/cobol-check/src

COPY --from=ghcr.io/astral-sh/uv:0.12 /uv /uvx /usr/local/bin/

# Python deps live outside the bind-mounted workspace so a macOS .venv never
# collides with the Linux one.
ENV UV_PROJECT_ENVIRONMENT=/opt/venv \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never \
    PATH=/opt/venv/bin:/opt/gixsql/bin:$PATH \
    GIXSQL_HOME=/opt/gixsql \
    COBOLCHECK_HOME=/opt/cobol-check \
    IN_TOOLCHAIN=1

COPY pyproject.toml uv.lock /tmp/deps/
RUN cd /tmp/deps && uv sync --frozen --no-install-project && rm -rf /tmp/deps

WORKDIR /work
