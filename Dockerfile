FROM ubuntu:24.04

ARG version=6.34
ENV HEASOFT_VERSION=${version}

LABEL version="${version}" \
      description="HEASoft ${version} https://heasarc.gsfc.nasa.gov/lheasoft/" \
      maintainer="Bojan Todorkov"

# Install HEASoft prerequisites
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update \
 && apt -y upgrade \
 && apt -y install \
	gcc \
	gfortran \
	g++ \
	curl \
	libcurl4 \
	libcurl4-gnutls-dev \
	libncurses5-dev \
	libreadline6-dev \
	libfile-which-perl \
	libdevel-checklib-perl \
	make \
	ncurses-dev \
	perl-modules \
	vim \
	xorg-dev \
 && apt clean \
 && rm -rf /var/lib/apt/lists/*

RUN groupadd heasoft && useradd -r -m -g heasoft heasoft \
 && mkdir -p /opt/heasoft \
 && mkdir -p /opt/conda \
 && chown -R heasoft:heasoft /opt/heasoft \
 && chown -R heasoft:heasoft /opt/conda

USER heasoft
WORKDIR /home/heasoft

# Install conda
ADD --chown=heasoft:heasoft https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh miniconda.sh
RUN bash miniconda.sh -b -u -p /opt/conda && \
    rm miniconda.sh

RUN /opt/conda/bin/conda install python=3.12 astropy numpy scipy matplotlib setuptools

ENV CC=/usr/bin/gcc CXX=/usr/bin/g++ FC=/usr/bin/gfortran PERL=/usr/bin/perl PYTHON=/opt/conda/bin/python
RUN unset CFLAGS CXXFLAGS FFLAGS LDFLAGS build_alias host_alias

# Retrieve the HEASoft source code, unpack, configure,
# make, install, clean up, and create symlinks....
COPY --chown=heasoft:heasoft heasoft-${HEASOFT_VERSION} heasoft-${HEASOFT_VERSION}/
RUN cd heasoft-${HEASOFT_VERSION}/BUILD_DIR/ \
 && echo "Configuring heasoft..." \
 && ./configure --prefix=/opt/heasoft 2>&1 | tee ${HOME}/configure.log \
 && echo "Building heasoft..." \
 && make 2>&1 | tee ${HOME}/build.log \
 && echo "Installing heasoft..." \
 && make install 2>&1 | tee ${HOME}/install.log \
 && /bin/bash -c 'cd /opt/heasoft/; for loop in *64*/*; do ln -sf $loop; done' \
 && /bin/bash -c 'cd /opt/heasoft/bin; if test -f ${HOME}/heasoft-${HEASOFT_VERSION}/Xspec/BUILD_DIR/hmakerc; then cp ${HOME}/heasoft-${HEASOFT_VERSION}/Xspec/BUILD_DIR/hmakerc .; fi' \
 && /bin/bash -c 'if test -f ${HOME}/heasoft-${HEASOFT_VERSION}/Xspec/src/spectral; then rm -rf ${HOME}/heasoft-${HEASOFT_VERSION}/Xspec/src/spectral; fi' \
 && cd /opt/heasoft/bin \
 && ln -sf ../BUILD_DIR/Makefile-std \
 && rm -rf ${HOME}/heasoft-${HEASOFT_VERSION}

# Configure shells...
RUN /bin/echo >> /home/heasoft/.bashrc \
 && /bin/echo '# Initialize HEASoft environment' >> /home/heasoft/.bashrc \
 && /bin/echo 'export HEADAS=/opt/heasoft' >> /home/heasoft/.bashrc \
 && /bin/echo '. $HEADAS/headas-init.sh' >> /home/heasoft/.bashrc \
 && /bin/echo >> /home/heasoft/.bashrc \
 && /bin/echo >> /home/heasoft/.profile \
 && /bin/echo '# Initialize HEASoft environment' >> /home/heasoft/.profile \
 && /bin/echo 'export HEADAS=/opt/heasoft' >> /home/heasoft/.profile \
 && /bin/echo '. $HEADAS/headas-init.sh' >> /home/heasoft/.profile \
 && /bin/echo >> /home/heasoft/.profile

ENV PERLLIB=/opt/heasoft/lib/perl \
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

CMD [ "fversion" ]