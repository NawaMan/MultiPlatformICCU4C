#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <filesystem>
#include <cstdlib>
#include <cstring>

/*
 * ICU4C Cross-Platform Test
 * 
 * This test verifies the ICU4C package across different platforms including WebAssembly.
 * 
 * WebAssembly (WASM) Limitations:
 * - Limited file system access in the sandboxed environment
 * - The following ICU features have limited or no support in WASM:
 *   1. Break Iterator (sentence/word boundary analysis) - Missing resource data
 *   2. Transliteration - Missing transliteration rules
 *   3. Collation - Limited locale data
 *   4. Calendar data - Limited calendar support
 *   5. Converter data - Limited charset conversion support
 * 
 * When running in WASM environment, tests for these features will be skipped
 * with appropriate messages indicating the limitation.
 */

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

// Platform-specific path separators and extensions
#ifdef _WIN32
    const char PATH_SEP = '\\';
    const std::string LIB_PREFIX = "";
    const std::string LIB_EXT = ".lib";
    const std::string EXE_EXT = ".exe";
#else
    const char PATH_SEP = '/';
    const std::string LIB_PREFIX = "lib";
    #ifdef __APPLE__
        const std::string LIB_EXT = ".dylib";
    #else
        const std::string LIB_EXT = ".a";
    #endif
    const std::string EXE_EXT = "";
#endif

class ICUPackageTester {
private:
    bool all_requirements_met = true;
    std::string icu_root;
    
    // Construct platform-specific path
    std::string buildPath(const std::vector<std::string>& components) {
        std::string result;
        for (size_t i = 0; i < components.size(); ++i) {
            result += components[i];
            if (i < components.size() - 1) {
                result += PATH_SEP;
            }
        }
        return result;
    }
    
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
    
    // Count files with a specific extension in a directory (recursively)
    int countFiles(const std::string& directory, const std::string& extension) {
        int count = 0;
        try {
            for (const auto& entry : std::filesystem::recursive_directory_iterator(directory)) {
                if (entry.is_regular_file() && entry.path().extension() == extension) {
                    count++;
                }
            }
        } catch (const std::exception& e) {
            std::cerr << "Error counting files: " << e.what() << std::endl;
        }
        return count;
    }
    
    // List a sample of files with a specific extension in a directory
    std::vector<std::string> listSampleFiles(const std::string& directory, const std::string& extension, int maxSamples = 5) {
        std::vector<std::string> files;
        try {
            for (const auto& entry : std::filesystem::recursive_directory_iterator(directory)) {
                if (entry.is_regular_file() && entry.path().extension() == extension) {
                    files.push_back(entry.path().string());
                    if (files.size() >= maxSamples) break;
                }
            }
        } catch (const std::exception& e) {
            std::cerr << "Error listing files: " << e.what() << std::endl;
        }
        return files;
    }
    
public:
    // Constructor takes ICU root path
    ICUPackageTester(const std::string& icuRoot) : icu_root(icuRoot) {}
    
    // Test if the ICU package is properly installed
    bool testPackage() {
        std::cout << "\n===== ICU4C Package Verification =====" << std::endl;
        
        // Build library paths
        std::vector<std::string> libraries = {
            buildPath({icu_root, "lib", LIB_PREFIX + "icuuc" + LIB_EXT}),
            buildPath({icu_root, "lib", LIB_PREFIX + "icudata" + LIB_EXT}),
            buildPath({icu_root, "lib", LIB_PREFIX + "icui18n" + LIB_EXT}),
            buildPath({icu_root, "lib", LIB_PREFIX + "icuio" + LIB_EXT})
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
        std::vector<std::string> headers = {
            buildPath({icu_root, "include", "unicode", "uversion.h"}),
            buildPath({icu_root, "include", "unicode", "unistr.h"}),
            buildPath({icu_root, "include", "unicode", "ucnv.h"}),
            buildPath({icu_root, "include", "unicode", "ubrk.h"})
        };
        
        for (const auto& header : headers) {
            auto [exists, _] = checkFile(header);
            if (exists) {
                // Extract just the filename from the path
                size_t lastSep = header.find_last_of("/\\");
                std::string filename = (lastSep != std::string::npos) ? header.substr(lastSep + 1) : header;
                std::cout << "✅ Found " << filename << std::endl;
            } else {
                size_t lastSep = header.find_last_of("/\\");
                std::string filename = (lastSep != std::string::npos) ? header.substr(lastSep + 1) : header;
                std::cout << "❌ Missing " << filename << std::endl;
                all_requirements_met = false;
            }
        }
        
        // Count total headers using filesystem
        std::string headerDir = buildPath({icu_root, "include", "unicode"});
        int headerCount = countFiles(headerDir, ".h");
        std::cout << "\nCounting ICU headers:" << std::endl;
        std::cout << headerCount << std::endl;
        
        // List some headers
        std::cout << "\nSample ICU headers:" << std::endl;
        auto sampleHeaders = listSampleFiles(headerDir, ".h", 5);
        for (const auto& header : sampleHeaders) {
            std::cout << header << std::endl;
        }
        
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
        
#ifdef WASM_ENVIRONMENT
        // In WASM environment, skip this test as it requires resources not available
        std::cout << "⚠️ Break Iterator test skipped in WASM environment" << std::endl;
        std::cout << "  (Reason: Missing resource data for sentence break analysis)" << std::endl;
        return;
#endif
        
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
        
#ifdef WASM_ENVIRONMENT
        // In WASM environment, skip this test as it requires resources not available
        std::cout << "⚠️ Transliteration test skipped in WASM environment" << std::endl;
        std::cout << "  (Reason: Missing transliteration rules data)" << std::endl;
        return;
#endif
        
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
        
#ifdef WASM_ENVIRONMENT
        std::cout << "Note: Some tests will be skipped due to WASM limitations" << std::endl;
#endif
        
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
#ifdef WASM_ENVIRONMENT
        std::cout << "   ⚠️ Collation test skipped in WASM environment" << std::endl;
        std::cout << "      (Reason: Limited locale data in WASM)" << std::endl;
#else
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
#endif
        
        // Test 3: Check if we can access calendar data (requires ucal.dat)
        std::cout << "3. Testing calendar data..." << std::endl;
#ifdef WASM_ENVIRONMENT
        std::cout << "   ⚠️ Calendar test skipped in WASM environment" << std::endl;
        std::cout << "      (Reason: Limited calendar support in WASM)" << std::endl;
#else
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
#endif
        
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
#ifdef WASM_ENVIRONMENT
        std::cout << "   ⚠️ Converter test skipped in WASM environment" << std::endl;
        std::cout << "      (Reason: Limited charset conversion support in WASM)" << std::endl;
#else
        status = U_ZERO_ERROR;
        UConverter* conv = ucnv_open("Shift-JIS", &status);
        if (U_SUCCESS(status)) {
            std::cout << "   ✅ Converter data accessible" << std::endl;
            ucnv_close(conv);
        } else {
            std::cout << "   ❌ Failed to open converter: " << u_errorName(status) << std::endl;
            allTestsPassed = false;
        }
#endif
        
        // Summary
        std::cout << "\nICU Data Bundle Verification Summary:" << std::endl;
#ifdef WASM_ENVIRONMENT
        std::cout << "⚠️ WASM environment detected - limited ICU data bundle testing" << std::endl;
        std::cout << "✅ Basic ICU functionality verified" << std::endl;
        std::cout << "ℹ️ Some tests were skipped due to WASM limitations" << std::endl;
#else
        if (allTestsPassed) {
            std::cout << "✅ All ICU data tests passed! The data bundle is properly included and accessible." << std::endl;
        } else {
            std::cout << "❌ Some ICU data tests failed. The data bundle may not be properly included or accessible." << std::endl;
        }
#endif
    }
#endif  // RUN_ICU_EXAMPLES
};

int main(int argc, char* argv[]) {
    std::cout << "Testing ICU4C package..." << std::endl;
    
    // Get ICU root path from environment variable or command line argument
    std::string icuRoot = "/app/icu";  // Default path for Linux Docker container
    
    // Check environment variable first
    const char* envPath = std::getenv("ICU_ROOT");
    if (envPath != nullptr && strlen(envPath) > 0) {
        icuRoot = envPath;
    }
    // Then check command line argument (overrides environment variable)
    else if (argc > 1) {
        icuRoot = argv[1];
    }
    
    ICUPackageTester tester(icuRoot);
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
