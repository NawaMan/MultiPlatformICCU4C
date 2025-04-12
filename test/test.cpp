#include <unicode/unistr.h>
#include <iostream>

int main() {
    // Create an ICU UnicodeString and convert it to UTF-8
    icu::UnicodeString ustr = UNICODE_STRING_SIMPLE("Hello, ICU 🌍!");
    std::string utf8;
    ustr.toUTF8String(utf8);

    std::cout << utf8 << std::endl;
    return 0;
}
