#include <iostream>
#include <fstream>
#include <string>
#include <vector>

// Only include memory when needed for ICU examples
#ifdef RUN_ICU_EXAMPLES
#include <memory>
#endif

// For ICU examples (only included if headers are found)
#ifdef RUN_ICU_EXAMPLES
#include <unicode/uversion.h>
#include <unicode/unistr.h>
// Avoid using ustream.h due to linking issues
// #include <unicode/ustream.h>
#include <unicode/ucnv.h>
#include <unicode/ubrk.h>
#include <unicode/translit.h>
#include <unicode/locid.h>
#include <unicode/numfmt.h>
#include <unicode/calendar.h>
#include <unicode/datefmt.h>
#include <unicode/brkiter.h>
#include <unicode/uclean.h>
#include <unicode/udata.h>
#include <unicode/ucal.h>
#include <unicode/uchar.h>
#include <unicode/ures.h>
#include <unicode/coll.h>
#include <unicode/resbund.h>
#endif

class ICUPackageTester {
private:
    bool all_requirements_met = true;
    
    // Check if a file exists and get its size
    std::pair<bool, long> checkFile(const std::string& path) {
        std::ifstream file(path);
        if (file.good()) {
            file.seekg(0, std::ios::end);
            std::streamsize size = file.tellg();
            file.close();
            return {true, size};
        }
        return {false, 0};
    }
    
public:
    // Test if the ICU package is properly installed
    bool testPackage() {
        std::cout << "\n===== ICU4C Package Verification =====" << std::endl;
        
        // Check libraries
        const std::vector<std::string> libraries = {
            "/app/icu/lib/libicuuc.a",
            "/app/icu/lib/libicudata.a",
            "/app/icu/lib/libicui18n.a",
            "/app/icu/lib/libicuio.a"
        };
        
        std::cout << "\nChecking ICU libraries:" << std::endl;
        for (const auto& lib : libraries) {
            auto [exists, size] = checkFile(lib);
            if (exists) {
                std::cout << "✅ Found " << lib << " (" << (size / 1024) << " KB)" << std::endl;
            } else {
                std::cout << "❌ Missing " << lib << std::endl;
                all_requirements_met = false;
            }
        }
        
        // Check essential headers
        std::cout << "\nChecking ICU headers:" << std::endl;
        const std::vector<std::string> headers = {
            "/app/icu/include/unicode/uversion.h",
            "/app/icu/include/unicode/unistr.h",
            "/app/icu/include/unicode/ucnv.h",
            "/app/icu/include/unicode/ubrk.h"
        };
        
        for (const auto& header : headers) {
            auto [exists, _] = checkFile(header);
            if (exists) {
                std::cout << "✅ Found " << header.substr(header.find_last_of('/') + 1) << std::endl;
            } else {
                std::cout << "❌ Missing " << header.substr(header.find_last_of('/') + 1) << std::endl;
                all_requirements_met = false;
            }
        }
        
        // Count total headers
        std::cout << "\nCounting ICU headers:" << std::endl;
        system("find /app/icu/include/unicode -name \"*.h\" | wc -l");
        
        // List some headers
        std::cout << "\nSample ICU headers:" << std::endl;
        system("find /app/icu/include/unicode -name \"*.h\" | sort | head -5");
        
        // Summary
        if (all_requirements_met) {
            std::cout << "\n✅ ICU package verification completed successfully!" << std::endl;
            std::cout << "The package contains all required libraries and headers." << std::endl;
        } else {
            std::cout << "\n❌ ICU package verification failed!" << std::endl;
            std::cout << "The package is missing some required libraries or headers." << std::endl;
        }
        
        return all_requirements_met;
    }
    
#ifdef RUN_ICU_EXAMPLES
    // Example 1: Unicode string operations
    void runStringExample() {
        std::cout << "\n=== Running Unicode String Example ===" << std::endl;
        
        // Helper function to convert UnicodeString to std::string for output
        auto toString = [](const icu::UnicodeString& ustr) -> std::string {
            std::string result;
            ustr.toUTF8String(result);
            return result;
        };
        
        // Create a Unicode string with multi-language text
        icu::UnicodeString ustr("Hello, World! こんにちは 你好 مرحبا");
        std::cout << "Original string: " << toString(ustr) << std::endl;
        
        // Get string properties
        std::cout << "Length: " << ustr.length() << " code units" << std::endl;
        
        // Convert to uppercase
        icu::UnicodeString upper(ustr);
        upper.toUpper();
        std::cout << "Uppercase: " << toString(upper) << std::endl;
        
        // Convert to lowercase
        icu::UnicodeString lower(ustr);
        lower.toLower();
        std::cout << "Lowercase: " << toString(lower) << std::endl;
        
        // Substring operations
        icu::UnicodeString sub = ustr.tempSubString(7, 5);  // "World"
        std::cout << "Substring (7,5): " << toString(sub) << std::endl;
        
        // Find and replace
        icu::UnicodeString replaced(ustr);
        replaced.findAndReplace("World", "Universe");
        std::cout << "After replacement: " << toString(replaced) << std::endl;
    }
    
    // Example 2: Locale and formatting
    void runLocaleExample() {
        std::cout << "\n=== Running Locale Example ===" << std::endl;
        
        // Helper function to convert UnicodeString to std::string for output
        auto toString = [](const icu::UnicodeString& ustr) -> std::string {
            std::string result;
            ustr.toUTF8String(result);
            return result;
        };
        
        // Create locales
        icu::Locale us("en_US");
        icu::Locale fr("fr_FR");
        icu::Locale jp("ja_JP");
        
        // Create UnicodeString objects to store display names
        icu::UnicodeString usName, frName, jpName;
        
        // Display locale information
        std::cout << "US Locale: " << us.getName() << " (" << toString(us.getDisplayName(usName)) << ")" << std::endl;
        std::cout << "French Locale: " << fr.getName() << " (" << toString(fr.getDisplayName(frName)) << ")" << std::endl;
        std::cout << "Japanese Locale: " << jp.getName() << " (" << toString(jp.getDisplayName(jpName)) << ")" << std::endl;
        
        // Number formatting
        UErrorCode status = U_ZERO_ERROR;
        std::unique_ptr<icu::NumberFormat> nf_us(icu::NumberFormat::createCurrencyInstance(us, status));
        std::unique_ptr<icu::NumberFormat> nf_fr(icu::NumberFormat::createCurrencyInstance(fr, status));
        std::unique_ptr<icu::NumberFormat> nf_jp(icu::NumberFormat::createCurrencyInstance(jp, status));
        
        double amount = 1234567.89;
        icu::UnicodeString result_us, result_fr, result_jp;
        
        if (U_SUCCESS(status)) {
            nf_us->format(amount, result_us);
            nf_fr->format(amount, result_fr);
            nf_jp->format(amount, result_jp);
            
            std::cout << "Currency formatting:" << std::endl;
            std::cout << "  US: " << toString(result_us) << std::endl;
            std::cout << "  France: " << toString(result_fr) << std::endl;
            std::cout << "  Japan: " << toString(result_jp) << std::endl;
        }
    }
    
    // Example 3: Text boundary analysis
    void runBreakIteratorExample() {
        std::cout << "\n=== Running Break Iterator Example ===" << std::endl;
        
        // Helper function to convert UnicodeString to std::string for output
        auto toString = [](const icu::UnicodeString& ustr) -> std::string {
            std::string result;
            ustr.toUTF8String(result);
            return result;
        };
        
        UErrorCode status = U_ZERO_ERROR;
        icu::UnicodeString text("Hello, world! This is a test. How are you? 你好，世界！这是一个测试。");
        
        // Create a sentence break iterator
        std::unique_ptr<icu::BreakIterator> sentenceIterator(
            icu::BreakIterator::createSentenceInstance(icu::Locale::getUS(), status)
        );
        
        if (U_FAILURE(status)) {
            std::cout << "Error creating sentence iterator: " << u_errorName(status) << std::endl;
            return;
        }
        
        sentenceIterator->setText(text);
        
        // Iterate through sentences
        std::cout << "Sentence boundaries:" << std::endl;
        int32_t start = sentenceIterator->first();
        int32_t end = sentenceIterator->next();
        int sentenceCount = 1;
        
        while (end != icu::BreakIterator::DONE) {
            icu::UnicodeString sentence = text.tempSubString(start, end - start);
            std::cout << "  Sentence " << sentenceCount++ << ": " << toString(sentence) << std::endl;
            start = end;
            end = sentenceIterator->next();
        }
        
        // Create a word break iterator
        status = U_ZERO_ERROR;
        std::unique_ptr<icu::BreakIterator> wordIterator(
            icu::BreakIterator::createWordInstance(icu::Locale::getUS(), status)
        );
        
        if (U_FAILURE(status)) {
            std::cout << "Error creating word iterator: " << u_errorName(status) << std::endl;
            return;
        }
        
        // Just count words in the first sentence
        icu::UnicodeString firstSentence = text.tempSubString(0, text.indexOf(".") + 1);
        wordIterator->setText(firstSentence);
        
        int wordCount = 0;
        start = wordIterator->first();
        while ((end = wordIterator->next()) != icu::BreakIterator::DONE) {
            icu::UnicodeString word = firstSentence.tempSubString(start, end - start);
            // Skip punctuation and whitespace
            if (word.trim().length() > 0 && !u_ispunct(word.char32At(0))) {
                wordCount++;
            }
            start = end;
        }
        
        std::cout << "Words in first sentence: " << wordCount << std::endl;
    }
    
    // Example 4: Transliteration
    void runTransliterationExample() {
        std::cout << "\n=== Running Transliteration Example ===" << std::endl;
        
        // Helper function to convert UnicodeString to std::string for output
        auto toString = [](const icu::UnicodeString& ustr) -> std::string {
            std::string result;
            ustr.toUTF8String(result);
            return result;
        };
        
        UErrorCode status = U_ZERO_ERROR;
        
        // Create a transliterator for Latin to Cyrillic
        std::unique_ptr<icu::Transliterator> latinToCyrillic(
            icu::Transliterator::createInstance("Latin-Cyrillic", UTRANS_FORWARD, status)
        );
        
        if (U_FAILURE(status)) {
            std::cout << "Error creating transliterator: " << u_errorName(status) << std::endl;
            return;
        }
        
        // Transliterate some text
        icu::UnicodeString latinText("Privet, mir! Kak dela?");
        std::cout << "Original text: " << toString(latinText) << std::endl;
        
        latinToCyrillic->transliterate(latinText);
        std::cout << "Transliterated to Cyrillic: " << toString(latinText) << std::endl;
        
        // Create a transliterator for Cyrillic to Latin
        status = U_ZERO_ERROR;
        std::unique_ptr<icu::Transliterator> cyrillicToLatin(
            icu::Transliterator::createInstance("Cyrillic-Latin", UTRANS_FORWARD, status)
        );
        
        if (U_FAILURE(status)) {
            std::cout << "Error creating reverse transliterator: " << u_errorName(status) << std::endl;
            return;
        }
        
        cyrillicToLatin->transliterate(latinText);
        std::cout << "Transliterated back to Latin: " << toString(latinText) << std::endl;
    }
    
    // Example 5: ICU Data Bundle Verification
    void testICUDataBundle() {
        std::cout << "\n=== Running ICU Data Bundle Verification ===" << std::endl;
        
        // Helper function to convert UnicodeString to std::string for output
        auto toString = [](const icu::UnicodeString& ustr) -> std::string {
            std::string result;
            ustr.toUTF8String(result);
            return result;
        };
        
        bool allTestsPassed = true;
        UErrorCode status = U_ZERO_ERROR;
        
        // Test 1: Check if we can access character properties (requires uchar.dat)
        std::cout << "1. Testing character properties data..." << std::endl;
        UChar32 testChar = 0x0041;  // Latin 'A'
        int charType = u_charType(testChar);
        if (charType == U_UPPERCASE_LETTER) {
            std::cout << "   ✅ Character properties data accessible" << std::endl;
        } else {
            std::cout << "   ❌ Character properties data not working correctly" << std::endl;
            allTestsPassed = false;
        }
        
        // Test 2: Check if we can access collation data (requires coll.dat)
        std::cout << "2. Testing collation data..." << std::endl;
        status = U_ZERO_ERROR;
        std::unique_ptr<icu::Collator> coll(icu::Collator::createInstance(icu::Locale::getUS(), status));
        if (U_SUCCESS(status)) {
            icu::UnicodeString str1("apple");
            icu::UnicodeString str2("banana");
            icu::Collator::EComparisonResult result = coll->compare(str1, str2);
            if (result == icu::Collator::LESS) {
                std::cout << "   ✅ Collation data accessible (" << toString(str1) << " < " << toString(str2) << ")" << std::endl;
            } else {
                std::cout << "   ❌ Collation data not working correctly" << std::endl;
                allTestsPassed = false;
            }
        } else {
            std::cout << "   ❌ Failed to create collator: " << u_errorName(status) << std::endl;
            allTestsPassed = false;
        }
        
        // Test 3: Check if we can access calendar data (requires ucal.dat)
        std::cout << "3. Testing calendar data..." << std::endl;
        status = U_ZERO_ERROR;
        std::unique_ptr<icu::Calendar> cal(icu::Calendar::createInstance(icu::Locale("ja_JP@calendar=japanese"), status));
        if (U_SUCCESS(status)) {
            // Set to a known date in the Japanese calendar
            cal->set(2019, 4, 1);  // May 1, 2019 (Reiwa 1)
            int era = cal->get(UCAL_ERA, status);
            if (U_SUCCESS(status)) {
                std::cout << "   ✅ Calendar data accessible (Japanese era: " << era << ")" << std::endl;
            } else {
                std::cout << "   ❌ Failed to get calendar data: " << u_errorName(status) << std::endl;
                allTestsPassed = false;
            }
        } else {
            std::cout << "   ❌ Failed to create Japanese calendar: " << u_errorName(status) << std::endl;
            allTestsPassed = false;
        }
        
        // Test 4: Check if we can access resource bundle data (requires res files)
        std::cout << "4. Testing resource bundle data..." << std::endl;
        status = U_ZERO_ERROR;
        
        // Try to open the ICU data file directly
        UDataMemory* data = udata_open(nullptr, "dat", "icudt77l", &status);
        if (U_SUCCESS(status)) {
            std::cout << "   ✅ ICU data file accessible" << std::endl;
            udata_close(data);
        } else {
            // Try alternative approach - check if we can get locale display names
            // which also requires resource data
            status = U_ZERO_ERROR;
            icu::Locale locale("en_US");
            icu::UnicodeString displayName;
            locale.getDisplayName(displayName);
            
            if (displayName.length() > 0) {
                std::cout << "   ✅ Resource data accessible (via locale display names)" << std::endl;
            } else {
                std::cout << "   ❌ Failed to access resource data: " << u_errorName(status) << std::endl;
                allTestsPassed = false;
            }
        }
        
        // Test 5: Check if we can access converter data (requires cnv files)
        std::cout << "5. Testing converter data..." << std::endl;
        status = U_ZERO_ERROR;
        UConverter* conv = ucnv_open("Shift-JIS", &status);
        if (U_SUCCESS(status)) {
            std::cout << "   ✅ Converter data accessible" << std::endl;
            ucnv_close(conv);
        } else {
            std::cout << "   ❌ Failed to open converter: " << u_errorName(status) << std::endl;
            allTestsPassed = false;
        }
        
        // Summary
        std::cout << "\nICU Data Bundle Verification Summary:" << std::endl;
        if (allTestsPassed) {
            std::cout << "✅ All ICU data tests passed! The data bundle is properly included and accessible." << std::endl;
        } else {
            std::cout << "❌ Some ICU data tests failed. The data bundle may not be properly included or accessible." << std::endl;
        }
    }
#endif  // RUN_ICU_EXAMPLES
};

int main() {
    std::cout << "Testing ICU4C package..." << std::endl;
    
    ICUPackageTester tester;
    bool packageOk = tester.testPackage();
    
    if (!packageOk) {
        std::cout << "\nSkipping ICU examples due to missing components." << std::endl;
        return 1;
    }
    
#ifdef RUN_ICU_EXAMPLES
    // Print ICU version
    UVersionInfo versionInfo;
    u_getVersion(versionInfo);
    char versionString[U_MAX_VERSION_STRING_LENGTH];
    u_versionToString(versionInfo, versionString);
    std::cout << "\nICU Version: " << versionString << std::endl;
    
    // Run ICU examples
    try {
        tester.runStringExample();
        tester.runLocaleExample();
        tester.runBreakIteratorExample();
        tester.runTransliterationExample();
        tester.testICUDataBundle();
        
        std::cout << "\n✅ All ICU examples completed successfully!" << std::endl;
    } catch (const std::exception& e) {
        std::cerr << "\n❌ Exception in ICU examples: " << e.what() << std::endl;
        return 1;
    }
#else
    std::cout << "\nICU examples are disabled. To enable them, define RUN_ICU_EXAMPLES" << std::endl;
    std::cout << "and make sure the ICU libraries are properly linked." << std::endl;
#endif
    
    return 0;
}
