if (NOT VCPKG_TARGET_IS_UWP)
    message(FATAL_ERROR "${PORT} only supports UWP")
endif()

if(EXISTS "${CURRENT_INSTALLED_DIR}/include/openssl/ssl.h")
  message(WARNING "Can't build openssl if libressl is installed. Please remove libressl, and try install openssl again if you need it. Build will continue but there might be problems since libressl is only a subset of openssl")
  set(VCPKG_POLICY_EMPTY_PACKAGE enabled)
  return()
endif()

if (VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
    set(UWP_PLATFORM  "arm")
elseif (VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    set(UWP_PLATFORM  "arm64")
elseif (VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    set(UWP_PLATFORM  "x64")
elseif (VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
    set(UWP_PLATFORM  "Win32")
else ()
    message(FATAL_ERROR "Unsupported architecture")
endif()

vcpkg_find_acquire_program(PERL)
vcpkg_find_acquire_program(JOM)
get_filename_component(JOM_EXE_PATH ${JOM} DIRECTORY)
get_filename_component(PERL_EXE_PATH ${PERL} DIRECTORY)
set(ENV{PATH} "$ENV{PATH};${PERL_EXE_PATH};${JOM_EXE_PATH}")

set(OPENSSL_VERSION 1.1.1d)

vcpkg_download_distfile(ARCHIVE
    URLS "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" "https://www.openssl.org/source/old/1.1.1/openssl-${OPENSSL_VERSION}.tar.gz"
    FILENAME "openssl-${OPENSSL_VERSION}.tar.gz"
    SHA512 2bc9f528c27fe644308eb7603c992bac8740e9f0c3601a130af30c9ffebbf7e0f5c28b76a00bbb478bad40fbe89b4223a58d604001e1713da71ff4b7fe6a08a7
)

vcpkg_extract_source_archive_ex(
  OUT_SOURCE_PATH SOURCE_PATH
  ARCHIVE ${ARCHIVE}
  PATCHES
    EnableUWPSupport.patch
)

vcpkg_find_acquire_program(NASM)
get_filename_component(NASM_EXE_PATH ${NASM} DIRECTORY)
set(ENV{PATH} "${NASM_EXE_PATH};$ENV{PATH}")

vcpkg_find_acquire_program(JOM)

set(OPENSSL_SHARED no-shared)
if(VCPKG_LIBRARY_LINKAGE STREQUAL dynamic)
  set(OPENSSL_SHARED shared)
endif()

set(CONFIGURE_COMMAND ${PERL} Configure
    enable-static-engine
    enable-capieng
    no-unit-test
    no-ssl2
    no-asm
    no-uplink
    -utf-8
    ${OPENSSL_SHARED}
)

if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
    set(OPENSSL_ARCH VC-WIN32-UWP)
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    set(OPENSSL_ARCH VC-WIN64A-UWP)
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
    set(OPENSSL_ARCH VC-WIN32-ARM-UWP)
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    set(OPENSSL_ARCH VC-WIN64-ARM-UWP)
else()
    message(FATAL_ERROR "Unsupported target architecture: ${VCPKG_TARGET_ARCHITECTURE}")
endif()

set(OPENSSL_MAKEFILE "makefile")

file(REMOVE_RECURSE ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg)


if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "release")

    # Copy openssl sources.
    message(STATUS "Copying openssl release source files...")
    file(GLOB OPENSSL_SOURCE_FILES ${SOURCE_PATH}/*)
    foreach(SOURCE_FILE ${OPENSSL_SOURCE_FILES})
        file(COPY ${SOURCE_FILE} DESTINATION "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
    endforeach()
    message(STATUS "Copying openssl release source files... done")
    set(SOURCE_PATH_RELEASE "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")

    set(OPENSSLDIR_RELEASE ${CURRENT_PACKAGES_DIR})

    message(STATUS "Configure ${TARGET_TRIPLET}-rel")
    vcpkg_execute_required_process(
        COMMAND ${CONFIGURE_COMMAND} ${OPENSSL_ARCH} "--prefix=${OPENSSLDIR_RELEASE}" "--openssldir=${OPENSSLDIR_RELEASE}" -FS
        WORKING_DIRECTORY ${SOURCE_PATH_RELEASE}
        LOGNAME configure-perl-${TARGET_TRIPLET}-${VCPKG_BUILD_TYPE}-rel
    )
    message(STATUS "Configure ${TARGET_TRIPLET}-rel done")

    message(STATUS "Build ${TARGET_TRIPLET}-rel")
    # Openssl's buildsystem has a race condition which will cause JOM to fail at some point.
    # This is ok; we just do as much work as we can in parallel first, then follow up with a single-threaded build.
    make_directory(${SOURCE_PATH_RELEASE}/inc32/openssl)
    execute_process(
        COMMAND ${JOM} -k -j $ENV{NUMBER_OF_PROCESSORS} -f ${OPENSSL_MAKEFILE} build_libs
        WORKING_DIRECTORY ${SOURCE_PATH_RELEASE}
        OUTPUT_FILE ${CURRENT_BUILDTREES_DIR}/build-${TARGET_TRIPLET}-rel-0-out.log
        ERROR_FILE ${CURRENT_BUILDTREES_DIR}/build-${TARGET_TRIPLET}-rel-0-err.log
    )
    vcpkg_execute_required_process(
        COMMAND nmake -f ${OPENSSL_MAKEFILE} install_dev
        WORKING_DIRECTORY ${SOURCE_PATH_RELEASE}
        LOGNAME build-${TARGET_TRIPLET}-rel-1)

    message(STATUS "Build ${TARGET_TRIPLET}-rel done")
endif()


if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
    # Copy openssl sources.
    message(STATUS "Copying openssl debug source files...")
    file(GLOB OPENSSL_SOURCE_FILES ${SOURCE_PATH}/*)
    foreach(SOURCE_FILE ${OPENSSL_SOURCE_FILES})
        file(COPY ${SOURCE_FILE} DESTINATION "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg")
    endforeach()
    message(STATUS "Copying openssl debug source files... done")
    set(SOURCE_PATH_DEBUG "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg")

    set(OPENSSLDIR_DEBUG ${CURRENT_PACKAGES_DIR}/debug)

    message(STATUS "Configure ${TARGET_TRIPLET}-dbg")
    vcpkg_execute_required_process(
        COMMAND ${CONFIGURE_COMMAND} debug-${OPENSSL_ARCH} "--prefix=${OPENSSLDIR_DEBUG}" "--openssldir=${OPENSSLDIR_DEBUG}" -FS
        WORKING_DIRECTORY ${SOURCE_PATH_DEBUG}
        LOGNAME configure-perl-${TARGET_TRIPLET}-${VCPKG_BUILD_TYPE}-dbg
    )
    message(STATUS "Configure ${TARGET_TRIPLET}-dbg done")

    message(STATUS "Build ${TARGET_TRIPLET}-dbg")
    make_directory(${SOURCE_PATH_DEBUG}/inc32/openssl)
    execute_process(
        COMMAND ${JOM} -k -j $ENV{NUMBER_OF_PROCESSORS} -f ${OPENSSL_MAKEFILE} build_libs
        WORKING_DIRECTORY ${SOURCE_PATH_DEBUG}
        OUTPUT_FILE ${CURRENT_BUILDTREES_DIR}/build-${TARGET_TRIPLET}-dbg-0-out.log
        ERROR_FILE ${CURRENT_BUILDTREES_DIR}/build-${TARGET_TRIPLET}-dbg-0-err.log
    )
    vcpkg_execute_required_process(
        COMMAND nmake -f ${OPENSSL_MAKEFILE} install_dev
        WORKING_DIRECTORY ${SOURCE_PATH_DEBUG}
        LOGNAME build-${TARGET_TRIPLET}-dbg-1)

    message(STATUS "Build ${TARGET_TRIPLET}-dbg done")
endif()

file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/certs)
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/private)
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/lib/engines-1_1)
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/certs)
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/lib/engines-1_1)
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/private)
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/include)



file(REMOVE
    ${CURRENT_PACKAGES_DIR}/bin/openssl.exe
    ${CURRENT_PACKAGES_DIR}/debug/bin/openssl.exe
    ${CURRENT_PACKAGES_DIR}/debug/openssl.cnf
    ${CURRENT_PACKAGES_DIR}/openssl.cnf
    ${CURRENT_PACKAGES_DIR}/ct_log_list.cnf
    ${CURRENT_PACKAGES_DIR}/ct_log_list.cnf.dist
    ${CURRENT_PACKAGES_DIR}/openssl.cnf.dist
    ${CURRENT_PACKAGES_DIR}/debug/ct_log_list.cnf
    ${CURRENT_PACKAGES_DIR}/debug/ct_log_list.cnf.dist
    ${CURRENT_PACKAGES_DIR}/debug/openssl.cnf.dist
)

if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
	file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/bin" "${CURRENT_PACKAGES_DIR}/debug/bin")
endif()

file(READ "${CURRENT_PACKAGES_DIR}/include/openssl/dtls1.h" _contents)
string(REPLACE "<winsock.h>" "<winsock2.h>" _contents "${_contents}")
file(WRITE "${CURRENT_PACKAGES_DIR}/include/openssl/dtls1.h" "${_contents}")

file(READ "${CURRENT_PACKAGES_DIR}/include/openssl/rand.h" _contents)
string(REPLACE "#  include <windows.h>" "#ifndef _WINSOCKAPI_\n#define _WINSOCKAPI_\n#endif\n#  include <windows.h>" _contents "${_contents}")
file(WRITE "${CURRENT_PACKAGES_DIR}/include/openssl/rand.h" "${_contents}")

vcpkg_copy_pdbs()

file(COPY ${CMAKE_CURRENT_LIST_DIR}/usage DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT})
file(INSTALL ${SOURCE_PATH}/LICENSE DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)

vcpkg_test_cmake(PACKAGE_NAME OpenSSL MODULE)
