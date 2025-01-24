ARG HEASOFT_VERSION

FROM scratch AS downloader

ARG HEASOFT_VERSION

ADD https://heasarc.gsfc.nasa.gov/FTP/software/lheasoft/lheasoft${HEASOFT_VERSION}/heasoft-${HEASOFT_VERSION}src.tar.gz heasoft.tar.gz

FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim AS base

ENV UV_NO_CACHE=1 \
    UV_SYSTEM_PYTHON=1

# Install HEASoft prerequisites
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get upgrade -y && apt-get dist-upgrade -y && \
	apt-get install -y --no-install-recommends \
    curl \
    gcc \
	gfortran \
	g++ \
	libcurl4 \
	libcurl4-gnutls-dev \
    libdevel-checklib-perl \
	libfile-which-perl \
    libgsl-dev \
    libncurses5-dev \
	libreadline6-dev \
	make \
	ncurses-dev \
	perl-modules \
	vim \
	xorg-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd heasoft && useradd -r -m -g heasoft heasoft \
    && mkdir -p /opt/heasoft \
    && chown -R heasoft:heasoft /opt/heasoft

RUN uv pip install astropy numpy scipy matplotlib setuptools \
    && uv cache clean

FROM base AS heasoft_builder

ARG HEASOFT_VERSION

ENV CC=/usr/bin/gcc CXX=/usr/bin/g++ FC=/usr/bin/gfortran
RUN unset CFLAGS CXXFLAGS FFLAGS LDFLAGS build_alias host_alias

# Retrieve the HEASoft source code, unpack, configure,
# make, install, clean up, and create symlinks....
COPY --from=downloader --chown=heasoft:heasoft heasoft.tar.gz ./
RUN tar xfz heasoft.tar.gz \
    && cd heasoft-${HEASOFT_VERSION} \
    && rm -r calet demo hitomixrism integral ixpe maxi nicer nustar suzaku swift

WORKDIR /heasoft-${HEASOFT_VERSION}/BUILD_DIR/

RUN ./configure --prefix=/opt/heasoft 2>&1
RUN make 2>&1
RUN make install 2>&1
RUN /bin/bash -c 'cd /opt/heasoft/; for loop in *64*/*; do ln -sf $loop; done' \
    && /bin/bash -c 'cd /opt/heasoft/bin; if test -f ${HOME}/heasoft-${HEASOFT_VERSION}/Xspec/BUILD_DIR/hmakerc; then cp ${HOME}/heasoft-${HEASOFT_VERSION}/Xspec/BUILD_DIR/hmakerc .; fi' \
    && /bin/bash -c 'if test -f ${HOME}/heasoft-${HEASOFT_VERSION}/Xspec/src/spectral; then rm -rf ${HOME}/heasoft-${HEASOFT_VERSION}/Xspec/src/spectral; fi' \
    && cd /opt/heasoft/bin \
    && ln -sf ../BUILD_DIR/Makefile-std

FROM base AS final

ARG HEASOFT_VERSION

LABEL version="${HEASOFT_VERSION}" \
      description="HEASoft ${HEASOFT_VERSION} https://heasarc.gsfc.nasa.gov/lheasoft/" \
      maintainer="Bojan Todorkov"

COPY --from=heasoft_builder --chown=heasoft:heasoft /opt/heasoft /opt/heasoft

ENV CC=/usr/bin/gcc CXX=/usr/bin/g++ FC=/usr/bin/gfortran \
    PERLLIB=/opt/heasoft/lib/perl \
    PERL5LIB=/opt/heasoft/lib/perl \
    PYTHONPATH=/opt/heasoft/lib/python:/opt/heasoft/lib \
    PATH=/opt/heasoft/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    HEADAS=/opt/heasoft \
    LHEASOFT=/opt/heasoft \
    FTOOLS=/opt/heasoft \
    LD_LIBRARY_PATH=/opt/heasoft/lib \
    LHEAPERL=/usr/bin/perl \
    PFCLOBBER=1 \
    PFILES=/home/heasoft/pfiles;/opt/heasoft/syspfiles \
    FTOOLSINPUT=stdin \
    FTOOLSOUTPUT=stdout \
    LHEA_DATA=/opt/heasoft/refdata \
    LHEA_HELP=/opt/heasoft/help \
    EXT=lnx \
    PGPLOT_FONT=/opt/heasoft/lib/grfont.dat \
    PGPLOT_RGB=/opt/heasoft/lib/rgb.txt \
    PGPLOT_DIR=/opt/heasoft/lib \
    POW_LIBRARY=/opt/heasoft/lib/pow \
    XRDEFAULTS=/opt/heasoft/xrdefaults \
    TCLRL_LIBDIR=/opt/heasoft/lib \
    XANADU=/opt/heasoft \
    XANBIN=/opt/heasoft

USER heasoft
WORKDIR /home/heasoft
RUN mkdir pfiles
SHELL ["/bin/bash", "-c"]
