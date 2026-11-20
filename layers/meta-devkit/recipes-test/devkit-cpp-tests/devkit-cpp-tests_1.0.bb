SUMMARY = "Catch2, fmt and spdlog C++ integration test for the DevKit"
DESCRIPTION = "An opt-in test binary for use in a non-production QEMU image."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://CMakeLists.txt file://test.cpp"
S = "${UNPACKDIR}"

inherit cmake

DEPENDS = "catch2 fmt spdlog"
