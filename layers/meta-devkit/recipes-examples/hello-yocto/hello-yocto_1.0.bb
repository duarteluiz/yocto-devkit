SUMMARY = "Small C++ demonstration for the Yocto DevKit"
DESCRIPTION = "A dependency-free C++ program installed into the QEMU test image."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://main.cpp"
S = "${UNPACKDIR}"

do_compile() {
    ${CXX} ${CXXFLAGS} ${LDFLAGS} "${S}/main.cpp" -o hello-yocto
}

do_install() {
    install -d "${D}${bindir}"
    install -m 0755 hello-yocto "${D}${bindir}/hello-yocto"
}
