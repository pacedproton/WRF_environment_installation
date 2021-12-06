#!/bin/bash

<<scriptdoc
This WRF environment installation script facilitates the building the dependencies of WRF/WRF-Chem/WPS.
 
All the necessary parameterization is to fill out the block marked for
required parameters and adapt the respective module environment_version names/versions. 

Environment main elements: RHEL/CentOS Linux, 
Intel OneAPI/Parallel Studio (see README for tested versions on both) 

See the README file for step-by-step instructions. 

scriptdoc


### begin required parameters ###

initialize() {
    export PREFIX=/binfs/lv71449/malexand3/wrf                    # format: <PREFIX>/{<CATEGORY>, <PACKAGES>}
    export CATEGORY='2111'

    export PLATFORM_ARCH='Intel-vsc'                       # {AMD-generic, INTEL-vsc}

    # Intel oneapi / Parallel Studio via module system: use environment_version below, otherwise define setup script location below.
    # export PARALLELSTUDIO_ENVIONMENTSCRIPT='/metstor_nfs/opt/intel/parallel_studio_xe_2020.1.102/psxevars.sh'

    declare -Ag environment_version                          # tested versions, adapt to your environment
    environment_version[intel]='compiler/compiler'   
    environment_version[intel-mpi]='mpi/2021.3.0'           # enter separate oneapi Base and HPC Toolkits if not combined
    environment_version[cmake]='cmake/3.15.1-intel-19.0.5.281-zbb4n77'
    environment_version[perl5]='perl/5.26.2-gcc-9.1.0-npgo6f5'
    environment_version[gettext]='gettext/0.19.8.1-intel-19.0.5.281-47ar2rz'
    environment_version[libiconv]='libiconv/1.15-intel-19.0.5.281-a24zavx'
    environment_version[texinfo]='texinfo/6.5-gcc-9.1.0-jbo5m2y'
    environment_version[help2man]='help2man/1.47.8-intel-19.0.5.281-k3tb6t4'

    declare -Ag environment_alternate
    environment_alternate[automake_1_13_4]='automake/1.13.4'   
    environment_alternate[automake_1_13_4_vsc4]=''   
    environment_alternate[automake_1_16_1]='automake/1.16.1-intel-19.1.1.217-dapdape' 
    environment_alternate[automake_1_16_3]='automake/1.16.3' 

    WRF_ENVIRONMENT=${PREFIX}/${CATEGORY}/wrf_environment.sh  # location for generated wrf environment file

    WRF_CHEM=1
    WRF_KPP=0
    WRFIO_NCD_LARGE_FILE_SUPPORT=1
    
    export OPTI='-O0'

    ### end required parameters ###

    export PACKAGES="${CATEGORY}/pkg-src"

    export check=''                             # possible values: 'check', empty string '' 
    export clean='clean'                        # 'clean', ''

    declare -Ag src_packages
    src_packages[zlib]='https://github.com/madler/zlib.git'
    src_packages[curl]='https://github.com/curl/curl'

    src_packages[libpng]='https://github.com/glennrp/libpng.git'
    src_packages[hdf5]='https://github.com/HDFGroup/hdf5'
    src_packages[netcdf_c]='https://github.com/Unidata/netcdf-c.git'
    src_packages[netcdf_f]='https://github.com/Unidata/netcdf-fortran.git'
    src_packages[pnetcdf]='https://github.com/Parallel-NetCDF/PnetCDF.git'
    src_packages[netcdf_pnetcdf]='https://github.com/Unidata/netcdf-c.git'
    src_packages[jasper]='https://github.com/mdadams/jasper.git'
    src_packages[wrf]='https://github.com/wrf-model/WRF.git'
    src_packages[wps]='https://github.com/wrf-model/WPS.git'
    src_packages[flex]='https://github.com/westes/flex.git'
    src_packages[yacc]='https://github.com/pacedproton/yacc.git'

    declare -Ag src_packages_version
    src_packages_version[zlib]='refs/tags/v1.2.11'
    src_packages_version[curl]='refs/tags/curl-7_68_0'
    src_packages_version[libpng]='refs/tags/v1.6.35'
    src_packages_version[jasper]='refs/tags/version-2.0.16'
    src_packages_version[wrf]='refs/tags/v4.2.2'
    src_packages_version[hdf5]='refs/tags/hdf5-1_12_0'
    src_packages_version[netcdf_c]='refs/tags/v4.7.3'
    src_packages_version[netcdf_f]='refs/tags/v4.5.2'
    src_packages_version[pnetcdf]='refs/tags/checkpoint.1.12.1'
    src_packages_version[flex]='refs/tags/v2.6.4'
    src_packages_version[yacc]='refs/tags/v1.9'

    if [[ $CMDARG == 'clean' ]]; then
	read -r -p "move ${PREFIX}/${CATEGORY} to ${PREFIX}/${CATEGORY}.save and delete ${PREFIX}/${PACKAGES} (yes/no)? " keyinput
        if [[ ${keyinput} =~ ^([nN][oO]|n|N)$ ]]; then
	    exit 0 
	elif [[ ${keyinput} =~ ^([yY][eE][sS]|[yY])$ ]] && [[ ! -z ${PREFIX} ]]; then
	    local categorypath="${PREFIX}/${CATEGORY}"
	    local categorypath_length="${#categorypath}"
	    local scriptpath_length="${#BASH_SOURCE[0]}"
            local scriptpath_minus_categorypath="${BASH_SOURCE[0]::$categorypath_length}"
	    if [[ $categorypath == $scriptpath_minus_categorypath ]]; then
		echo "script inside filesystem build tree; move it outside and retry"
		exit 1
            fi
	    if [[ -d ${PREFIX}/${CATEGORY}.save ]]; then
	        rm -rf ${PREFIX}/${CATEGORY}.save
            fi
	    mv -v ${PREFIX}/${CATEGORY} ${PREFIX}/${CATEGORY}.save
	    rm -vrf ${PREFIX}/${CATEGORY}.save/pkg-src
	    exit $?
	fi
    fi

    if [[ -f ${WRF_ENVIRONMENT} && $wps != 'wps' ]]; then
        truncate -s 0 ${WRF_ENVIRONMENT}
    fi

    mkdir -p ${PREFIX}/{${CATEGORY},${PACKAGES},common/${PACKAGES},tmp}

    processes=$(($(nproc) - $(cat /proc/loadavg | awk '{print int($1)}')))
}


buildclean () {
    unset src_packages
    unset src_packages_version
    unset environment_version

    PREFIX='#'
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
    PARALLELSTUDIO_ENVIONMENTSCRIPT=''
}

set_platform_parms(){
    echo $PLATFORM_ARCH
    if [[ ${PLATFORM_ARCH} == 'AMD-generic' ]]; then
	if [[ ! -z ${PARALLELSTUDIO_ENVIONMENTSCRIPT} ]]; then
	    source ${PARALLELSTUDIO_ENVIONMENTSCRIPT}
        else
            module load ${environment_version[intel]}
	fi
	export CPU='-march=core-avx2 -qopt-report=0'
	export MPI=${I_MPI_ROOT}

    elif [[ ${PLATFORM_ARCH} == 'Intel-vsc' ]]; then
        for i_module in "${!environment_version[@]}"; do
            echo ${environment_version[$i_module]}
            module load ${environment_version[$i_module]}
        done

	export MPI=$(( module show ${environment_version[intel-mpi]} 2>&1 ) | awk '$2 ~ /I_MPI_ROOT/ {print $3}')
	export CPU='-xHost -shared-intel'
    fi

    export CC=icc
    export CXX=icpc
    export MPICC=mpiicc
    export MPICXX=mpiicpc
    export MPIF90=mpiifort
    export MPIF77=mpiifort
    export F77=ifort
    export FC=mpiifort
    export F90=ifort

    export CFLAGS="${OPTI} ${CPU} -ip -no-prec-div -fPIC"




    if [[ $wps != 'wps' ]]; then
	export LD_LIBRARY_PATH_INITIAL=$LD_LIBRARY_PATH
    fi

    printf "module load %s\n" "${environment_version[intel]}" >> ${WRF_ENVIRONMENT}
    printf "export LD_LIBRARY_PATH_INITIAL=%s\n" "$LD_LIBRARY_PATH_INITIAL" >> ${WRF_ENVIRONMENT}
    printf "export MPI=%s\n" "$MPI" >> ${WRF_ENVIRONMENT}
} 

git_lazy_clone() {
    local this_package=$1

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
	git reset --hard
	git clean -d -f
	git checkout -f master
	if [[ -v ${src_packages_version[$this_package]} ]]; then
             git checkout ${src_packages_version[$this_package]}       
	else 
            git pull
	fi
    fi
}

line_printer() {
    if [[ $1 = 'wrf' ]]; then
	echo "\n\n\n[info] cloning WRF"
    else
	echo -e "\n\n\n[info] building $1"
    fi
}

cleanup_check() {
   local this_package_path="${1}"
   local ret_cleanup_check="not cleaned"
   if [[ -f ${this_package_path}/Makefile ]]; then
       make distclean
       ret_cleanup_check="prior Makefile found, build directory distcleaned"
       echo $ret_cleanup_check  
       return 0 
   fi
   ret_cleanup_check="no Makefile artifact found/build directory not cleaned"
   echo $ret_cleanup_check  
   return 0
}

zlib () {
    local this_package=${FUNCNAME[0]}
    line_printer ${FUNCNAME[0]}

    cd ${PREFIX}/${PACKAGES}

    git_lazy_clone $this_package ${src_packages[$this_package]} 

    cd ${PREFIX}/${PACKAGES}/${this_package}

#    module load ${environment_version[automake_1_16_3]}
    cleanup_check ${PREFIX}/${PACKAGES}/${this_package}
    ./configure --prefix=${PREFIX}/${CATEGORY}/${this_package} #remove -- static
    make install
    make $check 

    export ZLIB=${PREFIX}/${CATEGORY}/${this_package}
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${ZLIB}/lib

    printf "export ZLIB=%s\n" "$ZLIB" >> ${WRF_ENVIRONMENT}
}


curl () {
    local this_package=${FUNCNAME[0]}
    line_printer ${FUNCNAME[0]}

    cd ${PREFIX}/${PACKAGES}

    git_lazy_clone $this_package

    cd ${PREFIX}/${PACKAGES}/${this_package}
    
    cleanup_check ${PREFIX}/${PACKAGES}/${this_package}
    autoreconf -ivf
    ./configure --prefix=${PREFIX}/${CATEGORY}/${this_package} --with-openssl 
    make install -j $processes
    make $check -j $processes

    export CURL=${PREFIX}/${CATEGORY}/${this_package}
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${CURL}/lib

    printf "export CURL=%s\n" "$CURL" >> ${WRF_ENVIRONMENT}
}


hdf5 () {
    local this_package=${FUNCNAME[0]}
    line_printer ${FUNCNAME[0]}

    export CXXFLAGS="${OPTI} ${CPU} -ip"

    cd ${PREFIX}/${PACKAGES}

    git_lazy_clone $this_package
    
    cd ${PREFIX}/${PACKAGES}/${this_package}

    export CC=mpiicc
    export CXX=mpiicpc

    module load ${environment_alternate[automake_1_16_3]}    
    cleanup_check ${PREFIX}/${PACKAGES}/${this_package}
    autoreconf -if
    ./configure --prefix=${PREFIX}/${CATEGORY}/${this_package} \
        --enable-fortran \
        --enable-parallel \
        --with-pic \
        --enable-hl \
        --enable-build-mode=production \
        --with-zlib=${ZLIB}/lib

    make -j -l6
    make install
    make $check 

    export HDF5=${PREFIX}/${CATEGORY}/${this_package}
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH_INITIAL:${HDF5}/lib

    printf "export HDF5=%s\n" "$HDF5" >> ${WRF_ENVIRONMENT}
    printf "export PHDF5=%s\n" "$HDF5" >> ${WRF_ENVIRONMENT}
}


netcdf_c () {
    local this_package=${FUNCNAME[0]}
    line_printer ${FUNCNAME[0]}

    export CC=mpiicc
    export CXX=mpiicpc

    export CXXFLAGS="${OPTI} -ip -no-prec-div ${CPU} -fPIC"
    export FFLAGS="${OPTI} -ip -no-prec-div ${CPU} -fPIC"
    export LDFLAGS="-L${HDF5}/lib -L${ZLIB}/lib"
    export CPPFLAGS="-I${HDF5}/include -I${ZLIB}/include"

    cd ${PREFIX}/${PACKAGES}

    git_lazy_clone $this_package

    cd ${PREFIX}/${PACKAGES}/${this_package}

    module load ${environment_version[automake_1_16_3]}    
    cleanup_check ${PREFIX}/${PACKAGES}/${this_package}
    autoreconf -i -if
    ./configure --prefix=${PREFIX}/${CATEGORY}/${this_package} \
        --disable-dap \
        --enable-parallel-tests \
        --enable-benchmarks \
        --enable-netcdf-4

    make -j $processes
    make install
    make $check

    export NETCDF_C=${PREFIX}/${CATEGORY}/${this_package}
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${NETCDF_C}/lib

    printf "export NETCDF_C=%s\n" "$NETCDF_C" >> ${WRF_ENVIRONMENT}
}


netcdf_f () {
    local this_package=${FUNCNAME[0]}
    line_printer ${FUNCNAME[0]}

    export CXXFLAGS="${OPTI} ${CPU} -ip -no-prec-div -fPIC"
    export FFLAGS="${OPTI} ${CPU} -ip -no-prec-div -fPIC" 
    export LDFLAGS="-L${HDF5}/lib -L${ZLIB}/lib -L${NETCDF_C}/lib -L${CURL}/lib"
    export CPPFLAGS="-I${HDF5}/include -I${ZLIB}/include -I${NETCDF_C}/include -I${CURL}/include"

    local LIBS='-lnetcdf -lhdf5_hl -lhdf5 -lz -lcurl'

    cd ${PREFIX}/${PACKAGES}

    git_lazy_clone $this_package

    cd ${PREFIX}/${PACKAGES}/${this_package}


    cleanup_check ${PREFIX}/${PACKAGES}/${this_package}
    autoreconf -i -if
    ./configure --prefix=${PREFIX}/${CATEGORY}/${this_package} \
        --disable-shared \
        --enable-parallel-tests \
        --enable-large-file-tests 
    make $processes
    make $check 
    make install

    export NETCDF_F=${PREFIX}/${CATEGORY}/${this_package}
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${NETCDF_F}/lib

    printf "export NETCDF_F=%s\n" "$NETCDF_F" >> ${WRF_ENVIRONMENT}
} 


pnetcdf () {
    local this_package=${FUNCNAME[0]}
    line_printer ${FUNCNAME[0]}

    export CXXFLAGS="${OPTI} ${CPU} -ip -no-prec-div"
    export FFLAGS="${OPTI} ${CPU} -ip -no-prec-div"

    export CPPFLAGS="-I${HDF5}/include -I${ZLIB}/include"
    export LDFLAGS="-L${HDF5}/lib -L${ZLIB}/lib"

    cd ${PREFIX}/${PACKAGES}

    git_lazy_clone $this_package

    cd ${PREFIX}/${PACKAGES}/${this_package}

    export CC=icc
    export CXX=icpc
    
    module purge
    cleanup_check ${PREFIX}/${PACKAGES}/${this_package}
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
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${PNETCDF}/lib

    printf "export PNETCDF=%s\n" "$PNETCDF" >> ${WRF_ENVIRONMENT}
}


libpng () {
    local this_package=${FUNCNAME[0]}
    line_printer ${FUNCNAME[0]}

    export CXXFLAGS="${OPTI} ${CPU} -ip -no-prec-div -fPIC"
    export CPPFLAGS="-I${ZLIB}/include"
    export ZLIBLIB=${ZLIB}/lib
    export ZLIBINC=${ZLIB}/include
    export LDFLAGS="-L${ZLIB}/lib"

    cd ${PREFIX}/${PACKAGES}

    git_lazy_clone $this_package

    cd ${PREFIX}/${PACKAGES}/${this_package}

    case $PLATFORM_ARCH in
        Intel-vsc) 
            echo libpng intel
            ;;
        AMD-generic)
            echo libpng amd
            ;;
    esac 


    module load ${environment_version[automake_1_16_3]}    
    cleanup_check ${PREFIX}/${PACKAGES}/${this_package}
    autoreconf -if
    ./configure --prefix=${PREFIX}/${CATEGORY}/${this_package} \
        --enable-hardware-optimizations \
        --enable-intel-sse

    make $check -j $processes
    make install

    export LIBPNG=${PREFIX}/${CATEGORY}/${this_package}
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${LIBPNG}/lib

    printf "export LIBPNG=%s\n" "$LIBPNG" >> ${WRF_ENVIRONMENT}
}


jasper () {
    local this_package=${FUNCNAME[0]}
    line_printer ${FUNCNAME[0]}

    cd ${PREFIX}/${PACKAGES}

    git_lazy_clone $this_package

    cd ${PREFIX}/${PACKAGES}/${this_package}

    mkdir -p ${PREFIX}/${PACKAGES}/${this_package}/build

    if [[ ${PLATFORM_ARCH} == 'Intel-vsc' ]]; then
        echo debug
        module list
        cmake --version

    	cmake -G "Unix Makefiles" -H${PREFIX}/${PACKAGES}/${this_package} \
            -B${PREFIX}/${PACKAGES}/${this_package}/build \
            -DCMAKE_INSTALL_PREFIX=${PREFIX}/${CATEGORY}/${this_package} \
            -DJAS_ENABLE_OPENGL=false \
            -DJAS_ENABLE_SHARED=true \
            -DJAS_ENABLE_LIBJPEG=true \
            -DCMAKE_BUILD_TYPE=Release   
    elif [[${PLATFORM_ARCH} == 'AMD-generic' ]]; then
	cmake3 -G "Unix Makefiles" -H${PREFIX}/${PACKAGES}/${this_package} \
            -B${PREFIX}/${PACKAGES}/${this_package}/build \
            -DCMAKE_INSTALL_PREFIX=${PREFIX}/${CATEGORY}/${this_package} \
            -DJAS_ENABLE_OPENGL=false \
            -DJAS_ENABLE_SHARED=true \
            -DJAS_ENABLE_LIBJPEG=true \
            -DCMAKE_BUILD_TYPE=Release   
    fi
	
    cd ${PREFIX}/${PACKAGES}/${this_package}/build

    make clean libjasper -j $processes
    
    if [[ ${check} == 'check'  ]]; then
        make test ARGS="-V"
    fi    
    
    make install

    export JASPER=${PREFIX}/${CATEGORY}/${this_package}
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${JASPER}/lib

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
    cp -pv ${PREFIX}/${CATEGORY}/netcdf_c/bin/ncdump ${PREFIX}/${CATEGORY}/${this_package}/bin

    export NETCDF_CF=${PREFIX}/${CATEGORY}/${this_package}
    printf "export NETCDF_CF=%s\n" "$NETCDF_CF" >> ${WRF_ENVIRONMENT}
    printf "export NETCDF=%s\n" "$NETCDF_CF" >> ${WRF_ENVIRONMENT}
}


flex() {

    local this_package=${FUNCNAME[0]}
    line_printer ${FUNCNAME[0]}

    cd ${PREFIX}/${PACKAGES}

    git_lazy_clone $this_package

    cd ${PREFIX}/${PACKAGES}/${this_package}

    if [[ ${PLATFORM_ARCH} == 'AMD-generic' ]]; then    
        module load ${environment_alternate[automake_1_16_3]}
    elif [[ ${PLATFORM_ARCH} == 'Intel-vsc' ]]; then
        module load ${environment_alternate[automake_1_16_1]}
        module load ${environment_version[gettext]}
    fi
    
    cleanup_check ${PREFIX}/${PACKAGES}/${this_package}
    ./autogen.sh
    ./configure --prefix=${PREFIX}/${CATEGORY}/${this_package} 

    make -j $processes
    make install

    export FLEX=${PREFIX}/${CATEGORY}/${this_package}
    export FLEX_LIB_DIR=${PREFIX}/${CATEGORY}/${this_package}/lib
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${FLEX}/lib

    printf "export FLEX=%s/bin/flex\n" "$FLEX" >> ${WRF_ENVIRONMENT}
    printf "export FLEX_LIB_DIR=%s\n" "$FLEX_LIB_DIR" >> ${WRF_ENVIRONMENT}
}


yacc() {
    local this_package=${FUNCNAME[0]}
    line_printer ${FUNCNAME[0]}

    cd ${PREFIX}/${PACKAGES}

    git_lazy_clone $this_package

    cd ${PREFIX}/${PACKAGES}/${this_package}

#    module load ${environment_version[automake_1_13_4]}    
    cleanup_check ${PREFIX}/${PACKAGES}/${this_package}
    ./configure --prefix=${PREFIX}/${CATEGORY}/${this_package} 
    make 
    make install

    export YACC="${PREFIX}/${CATEGORY}/${this_package}"
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${YACC}/lib

    printf "export \"YACC=%s/bin/yacc %s\"\n" "$YACC" '-d' >> ${WRF_ENVIRONMENT}
}


persist_ld_library_path () {
    export LD_LIBRARY_PATH="$LD_LIBRARY_PATH_INITIAL:${HDF5}/lib:${ZLIB}/lib:${NETCDF_CF}/lib:${CURL}/lib:${PNETCDF}/lib:${LIBPNG}/lib:${NETCDF_C}/lib:${NETCDF_F}/lib:${JASPER}/lib64:${FLEX}/lib"
    printf "export LD_LIBRARY_PATH=%s\n" "$LD_LIBRARY_PATH" >> ${WRF_ENVIRONMENT}
}

generate_peroration () {
    printf "export PATH=%s:%s:%s:${PATH}\n" "${FLEX}/bin" "${YACC}/bin" "$NETCDF_CF/bin" >> ${WRF_ENVIRONMENT} 
   
    printf "echo \"[info] Build date $(date)\"\n" >> ${WRF_ENVIRONMENT} 
    printf "echo \"[info] Compiler: %s, MPI: %s\"\n" ${environment_version[intel]} ${environment_version[intel-mpi]} >> ${WRF_ENVIRONMENT}

    if [[ ${PLATFORM_ARCH} == 'INTEL-vsc' ]]; then
	printf 'echo \"[modules] loading modules\"\n' >> ${WRF_ENVIRONMENT}

	for i_module in "${!environment_version[@]}"; do
            printf "module load %s\n" "${environment_version[$i_module]}" >> ${WRF_ENVIRONMENT}
	done

	printf 'module list\n' >> ${WRF_ENVIRONMENT}
    fi
}


wrf () {
    local this_package=${FUNCNAME[0]}
    line_printer ${FUNCNAME[0]}

    export J=2   

    cd ${PREFIX}/${PACKAGES}

    git_lazy_clone $this_package

    cd ${PREFIX}/${PACKAGES}/${this_package}

    if [[ ${WRF_CHEM} == 1 ]]; then
        printf "export WRF_CHEM=1\n" >> ${WRF_ENVIRONMENT}
        printf "export WRF_NMM_CORE=0\n" >> ${WRF_ENVIRONMENT}
    fi

    if [[ ${WRF_KPP} == 1 ]]; then
        printf "export WRF_KPP=1\n" >> ${WRF_ENVIRONMENT}
    fi

    WRF_DIR=$WRF   
    export WRF=${PREFIX}/${PACKAGES}/${this_package}

    printf "export WRF_DIR=%s\n" "$WRF" >> ${WRF_ENVIRONMENT}
    printf "export WRFIO_NCD_LARGE_FILE_SUPPORT=%s\n" "$WRFIO_NCD_LARGE_FILE_SUPPORT" >> ${WRF_ENVIRONMENT}
    printf "export J=\"%s\"\n" "$J" >> ${WRF_ENVIRONMENT}
    printf "export WRF_EM_CORE=1\n" >> ${WRF_ENVIRONMENT}

    cat << EOF

    ################################################################################################

    cd to ${PREFIX}/${PACKAGES}/${this_package}

    source the generated WRF_ENVIRONMENT file: source ${PREFIX}/${CATEGORY}/wrf_environment.sh
    
    ./configure

    select DMPAR - Intel (15) 

    edit configure.wrf, e.g. with
        DM_FC=mpiifort
        DM_CC=mpiicc
    
    compile model with e.g. ./compile <model name>
        for WRF-chem: additionally issue ./compile emi_conv

    issue ./clean before making changes to recompile or clean -a which also overwrites configure.wrf

    ################################################################################################


EOF
}


wps () {
    local this_package=${FUNCNAME[0]}
    line_printer ${FUNCNAME[0]}

    cd ${PREFIX}/${PACKAGES}

    git_lazy_clone $this_package
   
    cat <<EOF

    ################################################################################################

    run ./configure and select option 19 for Intel/distributed memory parallelism (dmpar)
    edit the resulting file configure.wps with: 
    DM_FC: mpiifort
    DM_CC: mpiicc
    LDFLAGS: -qopenmp

    then enter the library and include paths from the generated wrf_environment.sh file 
    (see paramter section for location) 
    
    COMPRESSION_LIBS=-L<jasperpath>/lib -L<zlibpath>/lib -L<libpngpath>/lib -ljasper -lpng -lz
    COMPRESSION_INC=-I<jasperpath>/include/jasper -I<zlibpath>/include -I<libpngpath>/include
    
    Example:

    COMPRESSION_LIBS=-L/gpfs/data/home/username/opt/jasper/lib64 -L/gpfs/data/data/home/usernameme/opt/zlib/lib -L/gpfs/data/data/home/username/opt/libpng/lib -ljasper -lpng -lz
    COMPRESSION_INC=-I/gpfs/data/home/username/opt/jasper/include/jasper -L/gpfs/data/home/username/opt/zlib/lib -L/gpfs/data/home/username/opt/libpng/lib

    then run ./compile
    issue clean before making changes to recompile or clean -a which also overwrites configure.wps
    
    ################################################################################################

EOF
}


main () {
    buildclean 
    initialize
    set_platform_parms
    curl
    libpng
    flex
    yacc
    zlib
#    curl
    hdf5
    netcdf_c
    netcdf_f
    netcdf_cf
    pnetcdf
#    libpng
    jasper
    persist_ld_library_path
    generate_peroration
    wrf
}


if [[ $1 == ${BASH_ARGV[0]} ]]; then
   export CMDARG=$1
fi 

if [[ $CMDARG == 'wps' ]]; then
    export wps='wps'
    initialize
    wps
    exit $?
fi

main "$@"

