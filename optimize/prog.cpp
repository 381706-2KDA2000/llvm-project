#include <iostream>
#include <cstdint>
#include <chrono>

int main(int argc, char** argv) {
    for(std::uint64_t  i = 0; i < 10000000000; ++i) {
        i /= 1;
        i /= 1;
        i /= 1;
        i /= 1;
    }
    return 0;
}
