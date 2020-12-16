#!/bin/zsh

#
# imagepreptest.zsh
#
# imageprep test harness
#
# @author    Tony Smith
# @copyright 2020, Tony Smith
# @version   1.0.0
# @license   MIT
#

test_app="$1"
image_src="$(pwd)/source"


fail() {
    echo "TEST $2 FAILED -- $1"
    exit  1
}

# TEST ONE
echo "Running tests...\nTEST 1..."
result=$("$test_app" -k -s "$image_src" -d test1 --createdirs -a s 100 100)

# Make sure sub-directory created
if [[ ! -e test1 ]]; then
    fail "Sub-directory 'test1' not created" 1
fi

# Make sure random image is 100px high
result=$(sips 'test1/BBC Space Themes.jpg' -g pixelHeight -1)
result=$(echo "$result" | cut -d "|" -f2)
if [[ "$result" != "  pixelHeight: 100" ]]; then
    fail "Scale to 100 x 100 failed" 1
fi

# Clear the output
rm -rf test1

# TEST TWO
echo "TEST 2..."
result=$("$test_app" -k -s "$image_src" -d test1 --createdirs -a c 200 100)

# Make sure sub-directory created
if [[ ! -e test1 ]]; then
    fail "Sub-directory 'test1' not created" 2
fi

# Make sure random image is 100px high
result=$(sips 'test1/BBC Space Themes.jpg' -g pixelHeight -1)
result=$(echo "$result" | cut -d "|" -f2)
if [[ "$result" != "  pixelHeight: 100" ]]; then
    fail "Crop to 200 x 100 failed" 2
fi

result=$(sips 'test1/BBC Space Themes.jpg' -g pixelWidth -1)
result=$(echo "$result" | cut -d "|" -f2)
if [[ "$result" != "  pixelWidth: 200" ]]; then
    fail "Crop to 200 x 100 failed" 2
fi

# Clear the output
rm -rf test1

# TEST THREE
echo "TEST 3..."
result=$("$test_app" -k -s "$image_src" -d test1 --createdirs -r 0)

# Make sure sub-directory NOT created
if [[ -e test1 ]]; then
    fail "Sub-directory 'test1' created" 3
fi

result=$(echo -e "$result" | grep 'Invalid DPI value selected:')
if [[ -z "$result" ]]; then
    fail "0dpi setting not trapped" 3
fi

# TEST FOUR
echo "TEST 4..."
result=$("$test_app")
result=$(echo -e "$result" | grep 'No actions specified')
if [[ -z "$result" ]]; then
    fail "No action args not trapped" 4
fi

# TEST FIVE
echo "TEST 5..."
mkdir test5
cd test5
result=$("$test_app" -k -a s 100 100)
result=$(echo -e "$result" | grep 'is empty')
if [[ -z "$result" ]]; then
    fail "Empty directory not trapped" 5
fi

# TEST SIX
echo "TEST 6..."
result=$("$test_app" -k -s test999 -a s 100 100)
result=$(echo -e "$result" | grep 'cannot be found')
if [[ -z "$result" ]]; then
    fail "Missing source directory not trapped" 6
fi

# TEST SEVEN
echo "TEST 7..."
result=$("$test_app" -k -s "$image_src" -d test99 -a s 100 100)

# Make sure sub-directory was not created
if [[ -e test99 ]]; then
    fail "Sub-directory 'test99' created" 7
fi

# Make sure the missing target was spotted
result=$(echo -e "$result" | grep 'cannot be found')
if [[ -z "$result" ]]; then
    fail "Missing target directory not trapped" 7
fi

# TEST EIGHT
echo "TEST 8..."
result=$("$test_app" -k -s "../source" -d test8 --createdirs -a s 100 100)

# Make sure sub-directory created
if [[ ! -e test8 ]]; then
    fail "Sub-directory 'test8' not created" 8
fi

# Make sure random image is 100px high
result=$(sips 'test8/BBC Space Themes.jpg' -g pixelHeight -1)
result=$(echo "$result" | cut -d "|" -f2)
if [[ "$result" != "  pixelHeight: 100" ]]; then
    fail "Scale to 100 x 100 failed" 8
fi

# TEST NINE
echo "TEST 9..."
result=$("$test_app" -k -s "../source" -d test9 --createdirs -a s 100 100 -f png)

# Make sure sub-directory created
if [[ ! -e test9 ]]; then
    fail "Sub-directory 'test9' not created" 9
fi

# Check a random file was converted
if [[ ! -e 'test9/Doctor Who Genesis of the Daleks.png' ]]; then
    fail "File not converted to pNG" 9
fi

# Make sure random image is scaled
result=$(sips 'test9/Out of this World.png' -g pixelHeight -1)
result=$(echo "$result" | cut -d "|" -f2)
if [[ "$result" != "  pixelHeight: 100" ]]; then
    fail "Scale to 100 x 100 failed" 9
fi

cd ..
rm -rf test5

# TEST TEN
echo "TEST 10..."
mkdir test10
cp "source/Out of this World.jpg" "test10/oow.jpg"
result=$("$test_app" -s test10/oow.jpg -d test10a --createdirs -a s 100 100)

# Make sure sub-directory created
if [[ ! -e test10a ]]; then
    fail "Sub-directory 'test10a' not created" 10
fi

# Make sure target file created
if [[ ! -e test10a/oow.jpg ]]; then
    fail "File 'oow.jpg' not created" 10
fi

# Make sure image is 100px high
result=$(sips test10a/oow.jpg -g pixelHeight -1)
result=$(echo "$result" | cut -d "|" -f2)
if [[ "$result" != "  pixelHeight: 100" ]]; then
    fail "Scale to 100 x 100 failed" 10
fi

# Make sure source file deleted (no -k switch)
if [[ -e test10/oow.jpg ]]; then
    fail "File 'oow.jpg' not deleted" 10
fi

rm -rf test10
rm -rf test10a

echo "TESTS PASSED"