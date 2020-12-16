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
test_num=1

fail() {
    echo "TEST $2 FAILED -- $1"
    exit  1
}

new_test() {
    ((test_num+=1))
    echo "TEST $test_num..."
}

check_dir_exists() {
    if [[ ! -e "$1" ]]; then
        fail "Sub-directory $1 not created" $2
    fi
}

check_dir_not_exists() {
    if [[ -e "$1" ]]; then
        fail "Sub-directory $1 created" $2
    fi
}

check_file_exists() {
    if [[ ! -e "$1" ]]; then
        fail "File $1 not created" $2
    fi
}

check_file_not_exists() {
    if [[ -e "$1" ]]; then
        fail "File $1 created" $2
    fi
}

# START
"$test_app" --version

# TEST -- scale images, create intermediate directories
echo "Running tests...\nTEST $test_num..."
result=$("$test_app" -k -s "$image_src" -d test1 --createdirs -a s 100 100)

# Make sure sub-directory created
check_dir_exists test1 $test_num

# Make sure random image is 100px high
result=$(sips 'test1/BBC Space Themes.jpg' -g pixelHeight -1)
result=$(echo "$result" | cut -d "|" -f2)
if [[ "$result" != "  pixelHeight: 100" ]]; then
    fail "Scale to 100 x 100 failed" $test_num
fi

# Clear the output
rm -rf test1

# TEST -- crop images, create intermediate directories
new_test
result=$("$test_app" -k -s "$image_src" -d test1 --createdirs -a c 200 100)

# Make sure sub-directory created
check_dir_exists test1 $test_num

# Make sure random image is 100px high
result=$(sips 'test1/BBC Space Themes.jpg' -g pixelHeight -1)
result=$(echo "$result" | cut -d "|" -f2)
if [[ "$result" != "  pixelHeight: 100" ]]; then
    fail "Crop to 200 x 100 failed" $test_num
fi

# Make sure random image is 100px wide
result=$(sips 'test1/BBC Space Themes.jpg' -g pixelWidth -1)
result=$(echo "$result" | cut -d "|" -f2)
if [[ "$result" != "  pixelWidth: 200" ]]; then
    fail "Crop to 200 x 100 failed" $test_num
fi

# Clear the output
rm -rf test1

# TEST -- bad DPI value spotted
new_test
result=$("$test_app" -k -s "$image_src" -d test1 --createdirs -r 0)

# Make sure sub-directory NOT created
check_dir_not_exists test1 $test_num

# Check for error message (invalid DPI) in output
result=$(echo -e "$result" | grep 'Invalid DPI value selected:')
if [[ -z "$result" ]]; then
    fail "0dpi setting not trapped" $test_num
fi

# TEST -- no actions spotted
new_test
result=$("$test_app")

# Check for error message (no actions) in output
result=$(echo -e "$result" | grep 'No actions specified')
if [[ -z "$result" ]]; then
    fail "No action args not trapped" $test_num
fi

# TEST -- no files in source directory spotted
new_test
mkdir test5
cd test5
result=$("$test_app" -k -a s 100 100)

# Check for error message (empty dir) in output
result=$(echo -e "$result" | grep 'is empty')
if [[ -z "$result" ]]; then
    fail "Empty directory not trapped" $test_num
fi

# TEST -- missing source directory spotted
new_test
result=$("$test_app" -k -s test6 -a s 100 100)

# Check for error message (dir does not exist) in output
result=$(echo -e "$result" | grep 'cannot be found')
if [[ -z "$result" ]]; then
    fail "Missing source directory not trapped" $test_num
fi

# TEST -- missing target directory spotted, no intermediates created
new_test
result=$("$test_app" -k -s "$image_src" -d test7 -a s 100 100)

# Make sure sub-directory was not created
check_dir_not_exists test7 $test_num

# Make sure the missing target was spotted (because not created)
result=$(echo -e "$result" | grep 'cannot be found')
if [[ -z "$result" ]]; then
    fail "Missing target directory not trapped" $test_num
fi

# TEST -- use of a relative path
new_test
result=$("$test_app" -k -s "../source" -d test8 --createdirs -a s 100 100)

# Make sure sub-directory created
check_dir_exists test8 $test_num

# Make sure random image is 100px high
result=$(sips 'test8/BBC Space Themes.jpg' -g pixelHeight -1)
result=$(echo "$result" | cut -d "|" -f2)
if [[ "$result" != "  pixelHeight: 100" ]]; then
    fail "Scale to 100 x 100 failed" $test_num
fi

# TEST -- use a relative path, convert jpg -> png, create intermediate dirs, scale images
new_test
result=$("$test_app" -k -s "../source" -d test9 --createdirs -a s 100 100 -f png)

# Make sure sub-directory created
check_dir_exists test9 $test_num

# Check a random file was converted
if [[ ! -e 'test9/Doctor Who Genesis of the Daleks.png' ]]; then
    fail "File not converted to pNG" $test_num
fi

# Make sure random image is scaled
result=$(sips 'test9/Out of this World.png' -g pixelHeight -1)
result=$(echo "$result" | cut -d "|" -f2)
if [[ "$result" != "  pixelHeight: 100" ]]; then
    fail "Scale to 100 x 100 failed" $test_num
fi

cd ..
rm -rf test5

# TEST -- source image deleted
new_test
mkdir test10
cp "source/Out of this World.jpg" "test10/oow.jpg"
result=$("$test_app" -s test10/oow.jpg -d test10a --createdirs -a s 100 100)

# Make sure sub-directory created
check_dir_exists test10a $test_num

# Make sure target file created
check_file_exists test10a/oow.jpg $test_num

# Make sure image is 100px high
result=$(sips test10a/oow.jpg -g pixelHeight -1)
result=$(echo "$result" | cut -d "|" -f2)
if [[ "$result" != "  pixelHeight: 100" ]]; then
    fail "Scale to 100 x 100 failed" $test_num
fi

# Make sure source file deleted (no -k switch)
check_file_not_exists test10/oow.jpg $test_num

rm -rf test10
rm -rf test10a

echo "TESTS PASSED"