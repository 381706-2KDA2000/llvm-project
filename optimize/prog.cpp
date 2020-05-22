#include <iostream>
#include <cstdint>
#include <chrono>

int main(int argc, char** argv) {
    double a;
    for(std::uint64_t  i = 0; i < 10000000000; ++i, ++a) {
        i /= 1;
        i /= 1;
        i /= 1;
        i /= 1;
        a = 1.0 / a;
    }
    return 0;
}
