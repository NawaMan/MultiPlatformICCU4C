#include <iostream>
#include <string>
#include <unicode/unistr.h>
#include <unicode/uchar.h>
#include <unicode/ucnv.h>
#include <unicode/uversion.h>

int main() {
    // Print ICU version
    std::cout << "ICU Version: " << U_ICU_VERSION << std::endl;
    
    // Helper function to convert UnicodeString to std::string
    auto toString = [](const icu::UnicodeString& ustr) {
        std::string result;
        ustr.toUTF8String(result);
        return result;
    };

    // Create a Unicode string
    icu::UnicodeString ustr("Hello, World! 你好，世界！");
    std::cout << "Original string: " << toString(ustr) << std::endl;
    
    // String operations
    std::cout << "String length: " << ustr.length() << std::endl;
    std::cout << "Uppercase: " << toString(ustr.toUpper()) << std::endl;
    std::cout << "Lowercase: " << toString(ustr.toLower()) << std::endl;
    
    // Character properties
    UChar32 c = 0x1F600; // 😀 GRINNING FACE
    std::cout << "Character U+" << std::hex << c << " is ";
    if (u_isalpha(c)) {
        std::cout << "alphabetic";
    } else if (u_isdigit(c)) {
        std::cout << "a digit";
    } else if (u_ispunct(c)) {
        std::cout << "punctuation";
    } else if (u_isISOControl(c)) {
        std::cout << "a control character";
    } else {
        std::cout << "another type of character";
    }
    std::cout << std::endl;
    
    // Converter example
    UErrorCode status = U_ZERO_ERROR;
    UConverter *conv = ucnv_open("UTF-8", &status);
    if (U_FAILURE(status)) {
        std::cerr << "Failed to open converter: " << u_errorName(status) << std::endl;
        return 1;
    }
    
    std::cout << "Converter name: " << ucnv_getName(conv, &status) << std::endl;
    if (U_FAILURE(status)) {
        std::cerr << "Failed to get converter name: " << u_errorName(status) << std::endl;
        ucnv_close(conv);
        return 1;
    }
    
    ucnv_close(conv);
    
    std::cout << "\nAll ICU tests completed successfully!" << std::endl;
    return 0;
}
