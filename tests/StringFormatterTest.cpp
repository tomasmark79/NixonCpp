#include <Utils/String/StringFormatter.hpp>
#include <gtest/gtest.h>

using namespace nixoncpp::utils;

TEST(StringFormatterTest, AddDotsFormatsNumericStrings) {
  StringFormatter formatter;
  EXPECT_EQ(formatter.addDots(""), "");
  EXPECT_EQ(formatter.addDots("5"), "5");
  EXPECT_EQ(formatter.addDots("123"), "123");
  EXPECT_EQ(formatter.addDots("1000"), "1.000");
  EXPECT_EQ(formatter.addDots("1234567"), "1.234.567");
  EXPECT_EQ(formatter.addDots("1000000000"), "1.000.000.000");
}

TEST(StringFormatterTest, RemoveDotsStripsSeparators) {
  StringFormatter formatter;
  EXPECT_EQ(formatter.removeDots(""), "");
  EXPECT_EQ(formatter.removeDots("123"), "123");
  EXPECT_EQ(formatter.removeDots("1.000"), "1000");
  EXPECT_EQ(formatter.removeDots("1.234.567"), "1234567");
}

TEST(StringFormatterTest, AddAndRemoveDotsRoundTrip) {
  StringFormatter formatter;
  const std::string original = "9876543210";
  EXPECT_EQ(formatter.removeDots(formatter.addDots(original)), original);
}
