#include <catch2/catch_test_macros.hpp>
#include <fmt/format.h>
#include <spdlog/spdlog.h>

#include <cstdint>
#include <string>

namespace devkit {
[[nodiscard]] constexpr bool sensor_alarm(const int value, const int threshold) noexcept {
    return value >= threshold;
}

[[nodiscard]] std::string alarm_message(const int value) {
    return fmt::format("Sensor reading: {}", value);
}
} // namespace devkit

TEST_CASE("Sensor threshold trips only when reached", "[sensor]") {
    REQUIRE_FALSE(devkit::sensor_alarm(49, 50));
    REQUIRE(devkit::sensor_alarm(50, 50));
    REQUIRE(devkit::sensor_alarm(51, 50));
}

TEST_CASE("Message formatting provides a useful diagnostic", "[diagnostics]") {
    const auto message = devkit::alarm_message(42);
    REQUIRE(message == "Sensor reading: 42");
    spdlog::debug("Test diagnostic: {}", message);
}
