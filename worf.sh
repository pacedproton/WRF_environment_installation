#!/bin/bash

<<scriptdoc
This WRF environment installation script facilitates the building the dependencies of WRF/WPS.
 
All the necessary parameterization is to fill out the block marked for
required parameters. 

Environment: RHEL/CentOS Linux (tested 7.6)
Intel Parellel Studio (tested 19.1.0) 
cmake (tested 3.15.1)
perl (tested 5.26.2)

The Intel compilers, Intel MPI, cmake and perl need to be loadable
through the module facility. 

See the README file for step-by-step instructions. 

scriptdoc


### begin required parameters ###

initialize() {
    export PREFIX=${HOME}/tmp                   # format: <PREFIX>/{<CATEGORY>, <PACKAGES>}
    export CATEGORY='opt'
    export PACKAGES='packages'

    declare -Ag environment_version             # tested versions, adapt to your environment
    environment_version[intel]='intel/19.1.0'   
    environment_version[intel-mpi]='intel-mpi/2019.6'
    environment_version[cmake]='cmake/3.15.1-intel-19.0.5.281-zbb4n77'
    environment_version[perl5]='perl/5.26.2-gcc-9.1.0-npgo6f5'

    WRF_ENVIRONMENT=${PREFIX}/${PACKAGES}/wrf_environment.sh  # location for generated file
    WRF_CHEM=1
    WRFIO_NCD_LARGE_FILE_SUPPORT=1
    
    ### end required parameters ###


    export check='check'                        # possible values: 'check', empty string '' 
    export intelgnu='intel'                     # presently: 'intel' only
    export clean='clean'                        # 'clean', ''

    declare -Ag src_packages
    src_packages[zlib]='https://github.com/madler/zlib.git'
    src_packages[curl]='https://github.com/curl/curl'
    src_packages[libpng]='https://github.com/glennrp/libpng.git'
    src_packages[hdf5]='https://bitbucket.hdfgroup.org/scm/hdffv/hdf5.git'
    src_packages[netcdf_c]='https://github.com/Unidata/netcdf-c.git'
    src_packages[netcdf_f]='https://github.com/Unidata/netcdf-fortran.git'
    src_packages[pnetcdf]='https://github.com/Parallel-NetCDF/PnetCDF.git'
    src_packages[netcdf_pnetcdf]='https://github.com/Unidata/netcdf-c.git'
    src_packages[jasper]='https://github.com/mdadams/jasper.git'
    src_packages[wrf]='https://github.com/wrf-model/WRF.git'
    src_packages[wps]='https://github.com/wrf-model/WPS.git'

    declare -Ag src_packages_version
    src_packages_version[zlib]='refs/tags/v1.2.11'
    src_packages_version[curl]='refs/tags/curl-7_68_0'
    src_packages_version[libpng]='refs/tags/v1.6.35'
    src_packages_version[jasper]='refs/tags/version-2.0.16'
    src_packages_version[wrf]='refs/tags/v4.1.4'
    src_packages_version[hdf5]='hdf5_1_10_6'
    src_packages_version[netcdf_c]='refs/tags/v4.7.3'
    src_packages_version[netcdf_f]='refs/tags/v4.5.2'
    src_packages_version[pnetcdf]='refs/tags/checkpoint.1.12.1'

    ( [[ -f ${WRF_ENVIRONMENT} ]] && [[ $1 != 'wps' ]] ) && truncate -s 0 ${WRF_ENVIRONMENT}    

    mkdir -p ${PREFIX}/{${CATEGORY},${PACKAGES},common/${PACKAGES},tmp}

    processes=$(($(nproc) - $(cat /proc/loadavg | awk '{print int($1)}')))

    check_intelgnu
}

buildclean () {
    unset src_packages
    unset src_packages_version
    unset environment_version

    PREFIX=''
    CATEGORY=''
    PACKAGES=''

    check=''
    intelgnu=''
    clean=''
    processes=''

    MPI=''
    ZLIB=''
    NETCDF=''
    NETCDF_C=''
    NETCDF_F=''
    NETCDF_CF=''
    PNETCDF=''
    CURL=''
    LIBPNG=''
    HDF5=''
    JASPERINC=''
    JASPERLIB=''
    WRF_DIR=''
    WRFIO_NCD_LARGE_FILE_SUPPORT=''
    HDF5PATH=''
    WRF_CHEM=''
    CC=''
    CXX=''
    CPP=''
    CXXCPP=''
    MPIF77=''
    MPIF90=''
    MPICC=''
    MPICXX=''
    MPIF90=''
    MPIF77=''
    F77=''
    FC=''
    F90=''
    CFLAGS=''
    CXXFLAGS=''
    CPPFLAGS=''
    FFLAGS=''
    LDFLAGS=''
    
    if [[ ${clean} == 'clean' && ${BASH_ARGV[0]} == 'clean' ]]; then
	read -r -p "are you sure you want to move the libraries/binaries dir ${PREFIX}/${CATEGORY} to ${PREFIX}/${CATEGORY}.save (yes/no)? " keyinput
	if [[ ${keyinput} =~ ^([yY][eE][sS]|[yY])$  ]]; then
            mv ${PREFIX}/${CATEGORY} ${PREFIX}/${CATEGORY}.save
	fi
    fi
}

git_lazy_clone() {
    local this_package=$1

    echo $LD_LIBRARAY_PATH

    if [[ $this_package == '' ]]; then
        return 0
    fi

    local url=${src_packages[$this_package]}

    cd ${PREFIX}/${PACKAGES}

    if [[ ! -d ${PREFIX}/${PACKAGES}/$this_package ]]; then
	mkdir -p ${PREFIX}/${PACKAGES}
	cd ${PREFIX}/${PACKAGES}
	git clone -v $url $this_package
	cd ${PREFIX}/${PACKAGES}/${this_package} 
	git checkout ${src_packages_version[$this_package]}       
    else
	cd ${PREFIX}/${PACKAGES}/${this_package} 
	git clean -d -f
	git checkout -f master
	if [[ -v ${src_packages_version[$this_package]} ]]; then
            git checkout ${src_packages_version[$this_package]}       
	else 
            git pull
	fi
    fi
}

check_intelgnu() {
    if [[ ${intelgnu} == 'intel' ]]; then
        module load ${environment_version[intel]}
        module load ${environment_version[intel-mpi]}
        module load ${environment_version[cmake]}
        module load ${environment_version[perl5]}

        MPI=$(module path ${environment_version[intel-mpi]})
    else
        : # add GCC/OpenMPI
    fi

    if [[ "$1" != wps ]]; then
	export LD_LIBRARY_PATH_INITIAL=$LD_LIBRARY_PATH
    fi

    export MPI=$(module show ${environment_version[intel-mpi]} | awk '$2 ~ /VSC_MPI_BASE/ {print $3}')
    printf "export LD_LIBRARY_PATH_INITIAL=%s\n" "$LD_LIBRARY_PATH_INITIAL" >> ${WRF_ENVIRONMENT}
    printf "export MPI=%s\n" "$MPI" >> ${WRF_ENVIRONMENT}
}


line_printer() {
    echo -e "\n\n\n ***** $1 *****"
}

zlib () {
    local this_package=${FUNCNAME[0]}
    line_printer ${FUNCNAME[0]}

    export CC=icc
    export CFLAGS='-O3 -xHost -ip'

    cd ${PREFIX}/${PACKAGES}

    git_lazy_clone $this_package ${src_packages[$this_package]} ${src_packages_version[$this_package]}

    cd ${PREFIX}/${PACKAGES}/${this_package}

    make distclean

    ./configure --prefix=${PREFIX}/${CATEGORY}/${this_package} #remove -- static

    make $check 
    make install

    export ZLIB=${PREFIX}/${CATEGORY}/${this_package}
    printf "export ZLIB=%s\n" "$ZLIB" >> ${WRF_ENVIRONMENT}
}

curl () {
    local this_package=${FUNCNAME[0]}
    line_printer ${FUNCNAME[0]}

    export CC=icc
    export CFLAGS='-O3 -xHost -ip'

    cd ${PREFIX}/${PACKAGES}

    git_lazy_clone $this_package

    cd ${PREFIX}/${PACKAGES}/${this_package}

    autoreconf -if

    ./configure --prefix=${PREFIX}/${CATEGORY}/${this_package} 
    make $check -j $processes
    make install

    export CURL=${PREFIX}/${CATEGORY}/${this_package}
    printf "export CURL=%s\n" "$CURL" >> ${WRF_ENVIRONMENT}
}

hdf5 () {
    local this_package=${FUNCNAME[0]}
    line_printer ${FUNCNAME[0]}

    export CC=mpiicc
    export CXX=mpiicpc
    export FC=mpiifort
    export CFLAGS='-O3 -xHost -ip'
    export CXXFLAGS='-O3 -xHost -ip'
    export FCFLAGS='-O3 -xHost -ip'

    cd ${PREFIX}/${PACKAGES}

    git_lazy_clone $this_package

    cd ${PREFIX}/${PACKAGES}/${this_package}

    git checkout master
    git checkout ${src_packages_version[$this_package]}

    autoreconf -if
    ./configure --prefix=${PREFIX}/${CATEGORY}/${this_package} \
        --enable-fortran \
        --enable-parallel \
        --with-zlib=${ZLIB} \
        --with-pic \
        --enable-hl \
        --enable-build-mode=production \
        --with-zlib=${PREFIX}/${CATEGORY}/${ZLIB}/lib

    make -j -l6
    make install
    make $check 

    export HDF5=${PREFIX}/${CATEGORY}/${this_package}
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH_INITIAL:${ZLIB}/lib:${CURL}/lib:${HDF5}/lib

    printf "export HDF5=%s\n" "$HDF5" >> ${WRF_ENVIRONMENT}
    printf "export PHDF5=%s\n" "$HDF5" >> ${WRF_ENVIRONMENT}
}


netcdf_c () {
    local this_package=${FUNCNAME[0]}
    line_printer ${FUNCNAME[0]}

    export CC=mpiicc
    export CXX=mpiicpc
    export CPP='icc -E'
    export CXXCPP='icpc -E'
    export F77=mpiifort
    export FC=mpiifort
    export F90=mpiifort

    export CFLAGS='-O1 -xHost -ip -no-prec-div -shared-intel -fPIC'
    export CXXFLAGS='-O1 -xHost -ip -no-prec-div -shared-intel -fPIC'
    export FFLAGS='-O1 -xHost -ip -no-prec-div -fPIC' 

    export LDFLAGS="-L${HDF5}/lib -L${ZLIB}/lib -lhdf5 -lhdf5_hl -lz"
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH_INITIAL:${HDF5}/lib:${ZLIB}/lib:${CURL}/lib
    export CPPFLAGS="-I${HDF5}/include -I${ZLIB}/include"

    cd ${PREFIX}/${PACKAGES}

    git_lazy_clone $this_package

    git checkout master
    git checkout ${src_packages_version[$this_package]}

    cd ${PREFIX}/${PACKAGES}/${this_package}

    autoreconf -i -if
    ./configure --prefix=${PREFIX}/${CATEGORY}/${this_package} \
        --disable-dap \
        --enable-parallel-tests \
        --enable-benchmarks
    make -j $processes
    make install
    make $check

    export NETCDF_C=${PREFIX}/${CATEGORY}/${this_package}
    printf "export NETCDF_C=%s\n" "$NETCDF_C" >> ${WRF_ENVIRONMENT}
}


netcdf_f () {
    local this_package=${FUNCNAME[0]}
    line_printer ${FUNCNAME[0]}

    export CC=mpiicc
    export CXX=mpiicpc
    export CPP='icc -E'
    export CXXCPP='icpc -E'
    export F77=mpiifort
    export FC=mpiifort
    export F90=mpiifort

    export CFLAGS='-O1 -xHost -ip -no-prec-div -shared-intel -fPIC'
    export CXXFLAGS='-O1 -xHost -ip -no-prec-div -shared-intel -fPIC'
    export FFLAGS='-O1 -xHost -ip -no-prec-div -fPIC -shared-intel ' 

    export LDFLAGS="-L${HDF5}/lib -L${ZLIB}/lib -L${NETCDF_C}/lib -L${CURL}/lib"
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH_INITIAL:${HDF5}/lib:${ZLIB}/lib:${NETCDF_C}/lib:${CURL}/lib
    export CPPFLAGS="-I${HDF5}/include -I${ZLIB}/include -I${NETCDF_C}/include -I${CURL}/include"

    local LIBS='-lnetcdf -lhdf5_hl -lhdf5 -lz -lcurl'

    cd ${PREFIX}/${PACKAGES}

    git_lazy_clone $this_package

    git checkout master
    git checkout ${src_packages_version[$this_package]}

    cd ${PREFIX}/${PACKAGES}/${this_package}

    autoreconf -i -if
    ./configure --prefix=${PREFIX}/${CATEGORY}/${this_package} \
        --disable-shared \
        --enable-parallel-tests \
        --enable-large-file-tests 
    make clean
    make
    make $check 
    make install

    export NETCDF_F=${PREFIX}/${CATEGORY}/${this_package}
    printf "export NETCDF_F=%s\n" "$NETCDF_F" >> ${WRF_ENVIRONMENT}
} 


pnetcdf () {
    local this_package=${FUNCNAME[0]}
    line_printer ${FUNCNAME[0]}

    export CC=icc
    export CXX=icpc
    export MPICC=mpiicc
    export MPICXX=mpiicpc
    export MPIF90=mpiifort
    export MPIF77=mpiifort
    export CFLAGS='-O3 -xHost -ip -no-prec-div -shared-intel'
    export CXXFLAGS='-O3 -xHost -ip -no-prec-div -shared-intel'
    export F77=ifort
    export FC=ifort
    export F90=iifort
    export FFLAGS='-O3 -xHost -ip -no-prec-div -shared-intel'
    export CPP='icc -E'
    export CXXCPP='icpc -E'
    export CPPFLAGS="-I${HDF5}/include -I${ZLIB}/include"
    export LDFLAGS="-L${HDF5}/lib -L${ZLIB}/lib"
    export LD_LIBRARY_PATH=${HDF5}/lib:${ZLIB}/lib:${LD_LIBRARY_PATH_INITIAL}

    cd ${PREFIX}/${PACKAGES}

    git_lazy_clone $this_package

    git checkout master
    git checkout ${src_packages_version[$this_package]}

    cd ${PREFIX}/${PACKAGES}/${this_package}

    autoreconf -if
    ./configure --prefix=${PREFIX}/${CATEGORY}/${this_package} \
        --with-mpi=$MPI \
        --enable-shared \
        --enable-netcdf4 \
        --with-netcdf4=${NETCDF_C}

    make -j $processes

    if [[ $check == 'check' ]]; then
	make check
	make ptest
	make ptests
    fi

    make install

    export PNETCDF=${PREFIX}/${CATEGORY}/${this_package}
    printf "export PNETCDF_C=%s\n" "$PNETCDF" >> ${WRF_ENVIRONMENT}
}


libpng () {
    local this_package=${FUNCNAME[0]}
    line_printer ${FUNCNAME[0]}

    export CC=icc
    export CFLAGS='-O3 -xHost -ip'
    export CXXFLAGS='-O3 -xHost -ip -no-prec-div -shared-intel -fPIC'
    export CPPFLAGS="-I${ZLIB}/include"
    export ZLIBLIB=${ZLIB}/lib
    export ZLIBINC=${ZLIB}/include
    export LDFLAGS="-L${ZLIB}/lib"
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH_INITIAL:${ZLIB}/lib

    cd ${PREFIX}/${PACKAGES}

    git_lazy_clone $this_package

    git checkout master
    git checkout ${src_packages_version[$this_package]}


    cd ${PREFIX}/${PACKAGES}/${this_package}

    autoreconf -if
    ./configure --prefix=${PREFIX}/${CATEGORY}/${this_package} \
        --enable-hardware-optimizations \
        --enable-intel-sse

    make $check -j $processes
    make install

    export LIBPNG=${PREFIX}/${CATEGORY}/${this_package}
    printf "export LIBPNG=%s\n" "$LIBPNG" >> ${WRF_ENVIRONMENT}
}


jasper () {
    local this_package=${FUNCNAME[0]}
    line_printer ${FUNCNAME[0]}

    cd ${PREFIX}/${PACKAGES}

    git_lazy_clone $this_package

    cd ${PREFIX}/${PACKAGES}/${this_package}

    git checkout master
    git checkout ${src_packages_version[$this_package]}

    export CC=icc
    export CXX=icpc
    export F77=ifort

    mkdir -p ${PREFIX}/${PACKAGES}/${this_package}/build

    cmake -G "Unix Makefiles" -H${PREFIX}/${PACKAGES}/${this_package} \
        -B${PREFIX}/${PACKAGES}/${this_package}/build \
        -DCMAKE_INSTALL_PREFIX=${PREFIX}/${CATEGORY}/${this_package} \
        -DJAS_ENABLE_OPENGL=false \
        -DJAS_ENABLE_SHARED=true \
        -DJAS_ENABLE_LIBJPEG=true \
        -DCMAKE_BUILD_TYPE=Release   
    
    cd ${PREFIX}/${PACKAGES}/${this_package}/build

    make clean all -j $processes
    
    if [[ ${check} == 'check'  ]]; then
        make test ARGS="-V"
    fi    
    
    make install

    export JASPER=${PREFIX}/${CATEGORY}/${this_package}
    printf "export JASPER=%s\n" "$JASPER" >> ${WRF_ENVIRONMENT}
    printf "export JASPERINC=%s\n" "$JASPER/include/jasper" >> ${WRF_ENVIRONMENT}
    printf "export JASPERLIB=%s\n" "$JASPER/lib" >> ${WRF_ENVIRONMENT}
}


netcdf_cf() {
    local this_package=${FUNCNAME[0]}
    line_printer ${FUNCNAME[0]}

    mkdir -p ${PREFIX}/${CATEGORY}/${this_package}/{include,lib,bin}

    cp -pv ${PREFIX}/${CATEGORY}/netcdf_?/lib/* ${PREFIX}/${CATEGORY}/${this_package}/lib
    cp -pv ${PREFIX}/${CATEGORY}/netcdf_?/include/* ${PREFIX}/${CATEGORY}/${this_package}/include
    cp -pv ${PREFIX}/${CATEGORY}/netcdf_?/bin/n?-config ${PREFIX}/${CATEGORY}/${this_package}/bin

    export NETCDF_CF=${PREFIX}/${CATEGORY}/${this_package}
    printf "export PATH=$PATH:%s\n" "$NETCDF_CF/bin" >> ${WRF_ENVIRONMENT}
    printf "export NETCDF_CF=%s\n" "$NETCDF_CF" >> ${WRF_ENVIRONMENT}
    printf "export NETCDF=%s\n" "$NETCDF_CF" >> ${WRF_ENVIRONMENT}
}


persist_ld_library_path () {
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH_INITIAL:${HDF5}/lib:${ZLIB}/lib:${NETCDF_CF}/lib:${CURL}/lib:${PNETCDF}/lib:${LIBPNG}/lib:${NETCDF_C}/lib:${NETCDF_F}/lib:${JASPER}/lib
    printf "export LD_LIBRARY_PATH=%s\n" "$LD_LIBRARY_PATH" >> ${WRF_ENVIRONMENT}
}


wrf () {
    local this_package=${FUNCNAME[0]}
    line_printer ${FUNCNAME[0]}

    export JASPERLIB=${PREFIX}/${CATEGORY}/jasper/lib
    export JASPERINC=${PREFIX}/${CATEGORY}/jasper/include/jasper

    export F77=mpiifort
    export CXX=mpiicpc
    export CC=mpiicc
    export FFLAGS='-O3 -xHost -ip -no-prec-div'
    export CFLAGS='-O3 -xHost -ip -no-prec-div'
    export CPPFLAGS='-O3 -xHost -ip -no-prec-div'

    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH_INITIAL:${HDF5}/lib:${ZLIB}/lib:${NETCDF_CF}/lib:${CURL}/lib:${PNETCDF}/lib

    git checkout master
    git checkout ${src_packages_version[$this_package]}  

    export J="-j ${processes}"

    cd ${PREFIX}/${PACKAGES}

    git_lazy_clone $this_package

    cd ${PREFIX}/${PACKAGES}/${this_package}

    git checkout master
    git checkout ${src_packages_version[$this_package]}

    export WRF=${PREFIX}/${CATEGORY}/${this_package}
    WRF_DIR=$WRF   

    printf "export WRF_DIR=%s\n" "$WRF" >> ${WRF_ENVIRONMENT}

    cat << EOF

    ################################################################################################

    cd to ${PREFIX}/${PACKAGES}/${this_package}

    source the WRF_ENVIRONMENT file (default location: ${PREFIX}/${PACKAGES}/wrf_environment.sh)
    
    load the compiler module matching the parameter block, e.g.
    module load intel/19.1.0 

    load the MPI module matching the parameter block, e.g.
    module load intel-mpi/2019.6

    ./configure [-d without optimization]

    edit configure.wrf, e.g. with
        DM_FC=mpiifort
        DM_CC=mpiicc
    
    compile model with e.g. ./compile -j $processes <model name>
    
    issue clean before making changes to recompile or clean -a which also overwrites configure.wrf

    ################################################################################################


EOF
}


wps () {
    local this_package=${FUNCNAME[0]}
    line_printer ${FUNCNAME[0]}

    export CC=mpiicc
    export CXX=mpiicpc
    export CPP='icc -E'
    export CXXCPP='icpc -E'
    export F77=mpiifort
    export FC=mpiifort
    export F90=mpiifort

    export CFLAGS='-O1 -xHost -ip -no-prec-div -shared-intel -fPIC'
    export CXXFLAGS='-O1 -xHost -ip -no-prec-div -shared-intel -fPIC'
    export FFLAGS='-O1 -xHost -ip -no-prec-div -fPIC -shared-intel'
    export LDFLAGS='-qopenmp'

    cd ${PREFIX}/${PACKAGES}

    git_lazy_clone $this_package

    git checkout master
    git checkout ${src_packages_version[$this_package]}


    cat <<EOF

    ################################################################################################

    run ./configure and select option 19 for Intel/distributed memory parallelism
    edit the resulting file configure.wps with: 
    DM_FC: mpiifort
    DM_CC: mpiicc
    LDFAGS: -qoopenmp

    then enter the library and include paths from the generated wrf_environment.sh file 
    (see paramter section for location) 
    
    COMPRESSION_LIBS=-L<jasperpath>/lib -L<zlibpath>/lib -L<libpngpath>/lib -ljasper -lpng -lz
    COMPRESSION_INC=-I<jasperpath>/include -I<zlibpath>/include -I<libpngpath>/include
    
    Example:
    COMPRESSION_LIBS=-L/opt/worf/jasper/lib -L/opt/worf/zlib/lib -L/opt/worf/libpng/lib -ljasper -lpng -lz
    COMPRESSION_INC=-I/opt/worf/jasper/include/jasper -L/opt/worf/zlib/lib -L/opt/worf/libpng/lib

    then run ./compile
    issue clean before making changes to recompile or clean -a which also overwrites configure.wps
    
    ################################################################################################

EOF
}

main () {
    buildclean
    initialize
    zlib
    curl
    hdf5
    netcdf_c
    netcdf_f
    netcdf_cf
    pnetcdf
    libpng
    jasper
    persist_ld_library_path
    wrf
}

if [[ "$1" == wps ]]; then
    initialize
    wps
    exit $?
fi

main "$@"
