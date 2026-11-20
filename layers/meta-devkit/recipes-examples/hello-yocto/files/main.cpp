#include <iostream>
#include <string_view>

int main() {
    constexpr std::string_view message = "Hello from a C++ application built with Yocto!";
    std::cout << message << '\n';
    return 0;
}
