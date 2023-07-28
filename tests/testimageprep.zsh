#!/bin/zsh

#
# imagepreptest.zsh
#
# imageprep test harness
#
# @author    Tony Smith
# @copyright 2023, Tony Smith
# @version   2.0.0
# @license   MIT
#

if [ -z "$1" ]; then
    echo "Usage: ./imagepreptest.zsh path/to/test/binary"
    exit 1
fi

test_app="$1"
image_src="$(pwd)/source"
test_num=1

fail() {
    echo "\rTEST $2 FAILED @ LINE $3: $1 "
    exit  1
}

pass() {
    echo " PASSED"
}

new_test() {
    ((test_num+=1))
    echo -n "TEST $test_num..."
}

check_dir_exists() {
    if [[ ! -e "$1" ]]; then
        fail "Sub-directory $1 not created" $2 $LINENO
    fi
}

check_dir_not_exists() {
    if [[ -e "$1" ]]; then
        fail "Sub-directory $1 created" $2 $LINENO
    fi
}

check_file_exists() {
    if [[ ! -e "$1" ]]; then
        fail "File $1 not created" $2 $3
    fi
}

check_file_not_exists() {
    if [[ -e "$1" ]]; then
        fail "File $1 created" $2 $3
    fi
}

# Check test app exists
result=$(which "$test_app")
result=$(echo -e "$result" | grep 'not found')
if [[ -n "$result" ]]; then
    fail "Cannot access test file $test_app" "\b" $LINENO
fi

# START
"$test_app" --version

# TEST -- scale images, create intermediate directories
echo -n "Running tests...\nTEST $test_num..."
result=$("$test_app" -s "$image_src" -d test1 --createdirs -a s 100 100 2>&1)

# Make sure sub-directory created
check_dir_exists test1 $test_num

# Make sure random image is 100px high
result=$(sips 'test1/BBC Space Themes.jpg' -g pixelHeight -1)
result=$(echo "$result" | cut -d "|" -f2)
if [[ "$result" != "  pixelHeight: 100" ]]; then
    fail "Scale to 100 x 100 failed" $test_num $LINENO
fi

# Clear the output
rm -rf test1
pass

# TEST -- crop images, create intermediate directories
new_test
result=$("$test_app" -s "$image_src" -d test1 --createdirs -a c 200 100 2>&1)

# Make sure sub-directory created
check_dir_exists test1 $test_num

# Make sure random image is 100px high
result=$(sips 'test1/BBC Space Themes.jpg' -g pixelHeight -1)
result=$(echo "$result" | cut -d "|" -f2)
if [[ "$result" != "  pixelHeight: 100" ]]; then
    fail "Crop to 200 x 100 failed" $test_num $LINENO
fi

# Make sure random image is 100px wide
result=$(sips 'test1/BBC Space Themes.jpg' -g pixelWidth -1)
result=$(echo "$result" | cut -d "|" -f2)
if [[ "$result" != "  pixelWidth: 200" ]]; then
    fail "Crop to 200 x 100 failed" $test_num $LINENO
fi

# Clear the output
rm -rf test1
pass

# TEST -- bad DPI value spotted
new_test
result=$("$test_app" -s "$image_src" -d test1 --createdirs -r 0 2>&1)

# Make sure sub-directory NOT created
check_dir_not_exists test1 $test_num

# Check for error message (invalid DPI) in output
result=$(echo -e "$result" | grep 'Invalid DPI value selected:')
if [[ -z "$result" ]]; then
    fail "0dpi setting not trapped" $test_num $LINENO
fi

pass

# TEST -- bad colour value (too long) spotted
new_test
result=$("$test_app" -s "$image_src" -d test1 --createdirs -c 012345566789 2>&1)

# Make sure sub-directory NOT created
check_dir_not_exists test1 $test_num

# Check for error message (invalid colour) in output
result=$(echo -e "$result" | grep 'Invalid hex colour value supplied')
if [[ -z "$result" ]]; then
    echo "***"
    fail "Bad colour setting (too long) not trapped" $test_num $LINENO
fi

pass

# TEST -- bad colour value (not hex) spotted
new_test
result=$("$test_app" -s "$image_src" -d test1 --createdirs -c gg01aa 2>&1)

# Make sure sub-directory NOT created
check_dir_not_exists test1 $test_num

# Check for error message (invalid colour) in output
result=$(echo -e "$result" | grep 'Invalid hex colour value supplied')
if [[ -z "$result" ]]; then
    fail "Bad colour setting (bad hex) not trapped" $test_num $LINENO
fi

pass

# TEST -- bad format value spotted
new_test
result=$("$test_app" -s "$image_src" -d test1 --createdirs -f biff 2>&1)

# Make sure sub-directory NOT created
check_dir_not_exists test1 $test_num

# Check for error message (invalid colour) in output
result=$(echo -e "$result" | grep 'image format')
if [[ -z "$result" ]]; then
    fail "Bad format setting not trapped" $test_num $LINENO
fi

pass

# TEST -- bad switch (long) spotted
new_test
result=$("$test_app" -s "$image_src" -d test1 --createdirs --jump 2>&1)

# Make sure sub-directory NOT created
check_dir_not_exists test1 $test_num

# Check for error message (invalid colour) in output
result=$(echo -e "$result" | grep 'Unknown argument')
if [[ -z "$result" ]]; then
    fail "Bad switch not trapped" $test_num $LINENO
fi

pass

# TEST -- bad switch (short) spotted
new_test
result=$("$test_app" -s "$image_src" -d test1 --createdirs -z 2>&1)

# Make sure sub-directory NOT created
check_dir_not_exists test1 $test_num

# Check for error message (invalid colour) in output
result=$(echo -e "$result" | grep 'Unknown argument')
if [[ -z "$result" ]]; then
    fail "Bad switch not trapped" $test_num $LINENO
fi

pass

# TEST -- no files in source directory spotted
new_test
mkdir test5
cd test5
result=$("$test_app" -a s 100 100 2>&1)

# Check for error message (empty dir) in output
# NOTE use 'No files converted' for .enumerate() ; 'is empty' for .contentsOfDirectory()
result=$(echo -e "$result" | grep 'is empty') # Not an error, but an outcome
if [[ -z "$result" ]]; then
    fail "Empty directory not trapped" $test_num $LINENO
fi

pass

# TEST -- missing source directory spotted
new_test
result=$("$test_app" -s test6 -a s 100 100 2>&1)

# Check for error message (dir does not exist) in output
result=$(echo -e "$result" | grep 'cannot be found')
if [[ -z "$result" ]]; then
    fail "Missing source directory not trapped" $test_num $LINENO
fi

pass

# TEST -- missing target directory spotted, no intermediates created
new_test
result=$("$test_app" -s "$image_src" -d test7 -a s 100 100 2>&1)
# Make sure sub-directory was not created
check_dir_not_exists test7 $test_num

# Make sure the missing target was spotted (because not created)
result=$(echo -e "$result" | grep 'cannot be found')
if [[ -z "$result" ]]; then
    fail "Missing target directory not trapped" $test_num $LINENO
fi

pass

# TEST -- use of a relative path
new_test
result=$("$test_app" -s "../source" -d test8 --createdirs -a s 100 100 2>&1)

# Make sure sub-directory created
check_dir_exists test8 $test_num

# Make sure random image is 100px high
result=$(sips 'test8/Space Invaded.jpg' -g pixelHeight -1)
result=$(echo "$result" | cut -d "|" -f2)
if [[ "$result" != "  pixelHeight: 100" ]]; then
    fail "Scale to 100 x 100 failed" $test_num $LINENO
fi

pass

# TEST -- use a relative path, convert jpg -> png, create intermediate dirs, scale images
new_test
result=$("$test_app" -s "../source" -d test9 --createdirs -a s 100 100 -f png 2>&1)

# Make sure sub-directory created
check_dir_exists test9 $test_num

# Check a random file was converted
if [[ ! -e 'test9/Fourth Dimension.png' ]]; then
    fail "File not converted to PNG" $test_num $LINENO
fi

# Make sure random image is scaled
result=$(sips 'test9/Out of this World.png' -g pixelHeight -1)
result=$(echo "$result" | cut -d "|" -f2)
if [[ "$result" != "  pixelHeight: 100" ]]; then
    fail "Scale to 100 x 100 failed" $test_num $LINENO
fi

cd ..
rm -rf test5
pass

# TEST -- source image deleted
new_test
mkdir test10
cp "source/Out of this World.jpg" "test10/oow.jpg"
result=$("$test_app" -x -s test10/oow.jpg -d test10a --createdirs -a s 100 100 2>&1)

# Make sure sub-directory created
check_dir_exists test10a $test_num

# Make sure target file created
check_file_exists test10a/oow.jpg $test_num $LINENO

# Make sure image is 100px high
result=$(sips test10a/oow.jpg -g pixelHeight -1)
result=$(echo "$result" | cut -d "|" -f2)
if [[ "$result" != "  pixelHeight: 100" ]]; then
    fail "Scale to 100 x 100 failed" $test_num $LINENO
fi

# Make sure source file deleted (-x switch)
check_file_not_exists test10/oow.jpg $test_num $LINENO

rm -rf test10
rm -rf test10a
pass

# TEST -- source image deleted when it should not be
new_test
cp "source/Out of this World.jpg" oow.jpg
result=$("$test_app" -x -s oow.jpg -a s 150 150 2>&1)

# Make sure target file created
check_file_exists oow.jpg $test_num $LINENO

# Make sure image is 150px high
result=$(sips oow.jpg -g pixelHeight -1)
result=$(echo "$result" | cut -d "|" -f2)
if [[ "$result" != "  pixelHeight: 150" ]]; then
    fail "Scale to 150 x 150 failed" $test_num $LINENO
fi

rm oow.jpg
pass

# TEST -- source and dest are mismatched
new_test
result=$("$test_app" -x -s "$image_src" -d "test.jpg" --createdirs -a s 150 150 2>&1)

# Make sure the mismatch was spotted
result=$(echo -e "$result" | grep 'mismatched')
if [[ -z "$result" ]]; then
    fail "Mismatched source and destination not trapped" $test_num $LINENO
fi

pass

# TEST -- check bad scale width value
new_test
test_dir="test$test_num"
mkdir "$test_dir"
result=$("$test_app" -s "$image_src" -d "$test_dir" -a s 0 150 2>&1)

# Make sure the mismatch was spotted
result=$(echo -e "$result" | grep 'Invalid scale width')
if [[ -z "$result" ]]; then
    fail "Bad scale width not trapped" $test_num $LINENO
fi

pass

# TEST -- check bad scale height value
new_test
result=$("$test_app" -s "$image_src" -d "$test_dir" -a s 150 ZZZ 2>&1)

# Make sure the mismatch was spotted
result=$(echo -e "$result" | grep 'Invalid scale height')
if [[ -z "$result" ]]; then
    fail "Bad scale width not trapped" $test_num $LINENO
fi

pass

# TEST -- check bad crop width value
new_test
result=$("$test_app" -s "$image_src" -d "$test_dir" -a c AAA ZZZ 2>&1)

# Make sure the mismatch was spotted
result=$(echo -e "$result" | grep 'Invalid crop width')
if [[ -z "$result" ]]; then
    fail "Bad scale width not trapped" $test_num $LINENO
fi

pass

# TEST -- check bad crop height value
new_test
result=$("$test_app" -s "$image_src" -d "$test_dir" -a c 150 '£' 2>&1)

# Make sure the mismatch was spotted
result=$(echo -e "$result" | grep 'Invalid crop height')
if [[ -z "$result" ]]; then
    fail "Bad scale width not trapped" $test_num $LINENO
fi

pass

# TEST -- check bad pad width value
new_test
result=$("$test_app" -s "$image_src" -d "$test_dir" -a p A B 2>&1)

# Make sure the mismatch was spotted
result=$(echo -e "$result" | grep 'Invalid pad width')
if [[ -z "$result" ]]; then
    fail "Bad scale width not trapped" $test_num $LINENO
fi

pass

# TEST -- check bad pad height value
new_test
result=$("$test_app" -s "$image_src" -d "$test_dir" -a p 1 K 2>&1)

# Make sure the mismatch was spotted
result=$(echo -e "$result" | grep 'Invalid pad height')
if [[ -z "$result" ]]; then
    fail "Bad scale width not trapped" $test_num $LINENO
fi

rm -rf "$test_dir"
pass

# TEST -- check absent source file
new_test
test_file="zzz.png"
touch "$test_file"
result=$("$test_app" -s "$test_file" -a s 100 100 2>&1)

# Make sure the mismatch was spotted
result=$(echo -e "$result" | grep 'skipping')
if [[ -z "$result" ]]; then
    fail "Zero-content file not trapped" $test_num $LINENO
fi

rm "$test_file"
pass

# TEST -- check for bad action
new_test
result=$("$test_app" -s "$image_src" -a z 100 100 2>&1)

# Make sure the mismatch was spotted
result=$(echo -e "$result" | grep 'Invalid action selected')
if [[ -z "$result" ]]; then
    fail "Bad action not trapped" $test_num $LINENO
fi

pass

# TEST -- check for ignorable action
new_test
result=$("$test_app" -s "$image_src" -a s x x 2>&1)

# Make sure the mismatch was spotted
result=$(echo -e "$result" | grep 'No actions specified')
if [[ -z "$result" ]]; then
    fail "Ignorable actions not ignored" $test_num $LINENO
fi

pass

# TEST -- check for scale with raw image value (height)
new_test
mkdir "test$test_num"
result=$("$test_app" -s "$image_src" -d "test$test_num" -a s 1000 x 2>&1)

# Make sure random image is 1000 x 1500 high
result1=$(sips "test$test_num/BBC Space Themes.jpg" -g pixelHeight -1)
result2=$(sips "test$test_num/BBC Space Themes.jpg" -g pixelWidth -1)
result1=$(echo "$result1" | cut -d "|" -f2)
result2=$(echo "$result1" | cut -d "|" -f2)
if [[ "$result1" != "  pixelHeight: 1500" && "$result2" != "  pixelWidth: 1000" ]]; then
    fail "Scale to 1000 x image height failed" $test_num $LINENO
fi

rm -rf "test$test_num"
pass

# TEST -- check for scale with raw image value (width)
new_test
mkdir "test$test_num"
result=$("$test_app" -s "$image_src" -d "test$test_num" -a s x 800 2>&1)

# Make sure random image is 1000 x 1500 high
result1=$(sips "test$test_num/BBC Space Themes.jpg" -g pixelHeight -1)
result2=$(sips "test$test_num/BBC Space Themes.jpg" -g pixelWidth -1)
result1=$(echo "$result1" | cut -d "|" -f2)
result2=$(echo "$result1" | cut -d "|" -f2)
if [[ "$result1" != "  pixelHeight: 800" && "$result2" != "  pixelWidth: 1500" ]]; then
    fail "Scale to image width x 800 failed" $test_num $LINENO
fi

rm -rf "test$test_num"
pass

# TEST -- check for scale with aspect-ratio set image value (width)
new_test
result=$("$test_app" -s "$image_src/2000AD_0086_24.jpg" -a s 130 m 2>&1)

# Make sure random image is 130 x 160 high
result1=$(sips 2000AD_0086_24.jpg -g pixelHeight -1)
result2=$(sips 2000AD_0086_24.jpg -g pixelWidth -1)
result1=$(echo "$result1" | cut -d "|" -f2)
result2=$(echo "$result1" | cut -d "|" -f2)
if [[ "$result1" != "  pixelHeight: 160" && "$result2" != "  pixelWidth: 130" ]]; then
    fail "Scale to 130 by aspect ratio failed" $test_num $LINENO
fi

rm 2000AD_0086_24.jpg
pass

# TEST -- check for unknown crop fix point
new_test
result=$("$test_app" -s "$image_src/2000AD_0086_24.jpg" -a c 130 m --cropfrom gg 2>&1)

# Make sure the mismatch was spotted
result=$(echo -e "$result" | grep 'Invalid crop anchor')
if [[ -z "$result" ]]; then
    fail "Bad crop point not trapped" $test_num $LINENO
fi

pass

# TEST -- check for crop to bottom left
new_test
result=$("$test_app" -s "$image_src/2000AD_0086_24.jpg" -a c 650 800 --cropfrom br 2>&1)

# Make sure random image is 130 x 160 high
result1=$(sips 2000AD_0086_24.jpg -g pixelHeight -1)
result2=$(sips 2000AD_0086_24.jpg -g pixelWidth -1)
result1=$(echo "$result1" | cut -d "|" -f2)
result2=$(echo "$result1" | cut -d "|" -f2)
if [[ "$result1" != "  pixelHeight: 800" && "$result2" != "  pixelWidth: 650" ]]; then
    fail "Crop to 650 x 800 failed" $test_num $LINENO
fi

pass
echo "NOTE Manually verify 2000AD_0086_24.jpg is a bottom-right crop"

# TEST -- check crop offset
new_test
result=$("$test_app" -s "$image_src/2000AD_0086_24.jpg" -a c 229 231 --offset 285 97 -d 2000AD_0086_24b.jpg 2>&1)

# Make sure image is 229 x 231
result1=$(sips 2000AD_0086_24b.jpg -g pixelHeight -1)
result2=$(sips 2000AD_0086_24b.jpg -g pixelWidth -1)
result1=$(echo "$result1" | cut -d "|" -f2)
result2=$(echo "$result2" | cut -d "|" -f2)
if [[ "$result1" != "  pixelHeight: 231" && "$result2" != "  pixelWidth: 229" ]]; then
    fail "Crop to 229 x 231 failed" $test_num $LINENO
fi

pass
echo "NOTE Manually verify 2000AD_0086_24b.jpg is a Johnny Alpha face crop"

# TEST -- check for bad offset
new_test
result=$("$test_app" -s "$image_src/2000AD_0086_24.jpg" -a c 229 231 --offset -285 97 -d 2000AD_0086_24c.jpg 2>&1)

# Make sure bad offset trapped
result=$(echo -e "$result" | grep 'Invalid crop offset')
if [[ -z "$result" ]]; then
    fail "Bad crop offset not trapped" $test_num
fi

pass

# TEST -- check for bad arg trapping
new_test
result=$("$test_app" -s "$image_src/2000AD_0086_24.jpg" -a c 229 --offset -285 97 -d 2000AD_0086_24d.jpg 2>&1)

# Make sure bad offset trapped
result=$(echo -e "$result" | grep 'Missing value for')
if [[ -z "$result" ]]; then
    fail "Missing value not trapped" $test_num $LINENO
fi

pass

# TEST -- check for zero offset adjustments
new_test
result=$("$test_app" -s "$image_src/2000AD_0086_24.jpg" -a c 1300 300 --offset 0 100 -d 2000AD_0086_24e.jpg 2>&1)

# Make sure image os 1300 x 300
result1=$(sips 2000AD_0086_24e.jpg -g pixelHeight -1)
result2=$(sips 2000AD_0086_24e.jpg -g pixelWidth -1)
result1=$(echo "$result1" | cut -d "|" -f2)
result2=$(echo "$result2" | cut -d "|" -f2)
if [[ "$result1" != "  pixelHeight: 300" && "$result2" != "  pixelWidth: 1300" ]]; then
    fail "Crop to 1300 x 300 failed ($result1 x $result2)" $test_num $LINENO
fi

pass
echo "NOTE Manually verify 2000AD_0086_24e.jpg is a strip crop"

# TEST -- check for bad switch trapping #1
new_test
result=$("$test_app" -s "$image_src/2000AD_0086_24.jpg" -a c 100 100 --offset 10 10 -d 2000AD_0086_24d.jpg -k 2>&1)

# Make sure bad offset trapped
result=$(echo -e "$result" | grep 'Unknown argument:')
if [[ -z "$result" ]]; then
    fail "Missing value not trapped" $test_num $LINENO
fi

pass

# TEST -- check for bad switch trapping #2
new_test
result=$("$test_app" -s "$image_src/2000AD_0086_24.jpg" -a c 100 100 --offset 10 10 -d 2000AD_0086_24d.jpg --keep 2>&1)

# Make sure bad offset trapped
result=$(echo -e "$result" | grep 'Unknown argument:')
if [[ -z "$result" ]]; then
    fail "Missing value not trapped" $test_num $LINENO
fi

pass

# TEST -- check reformatting
new_test
result=$("$test_app" -s "$image_src/doctor.png" -a s 150 150 -f jpg -d . 2>&1)

check_file_exists doctor.jpg $test_num $LINENO

rm doctor.jpg
pass


# TEST -- check bad compression value
new_test
result=$("$test_app" -s "$image_src/doctor.png" -a s 150 150 -f jpg -j 1000 -d . 2>&1)

# Make sure bad value trapped
result=$(echo -e "$result" | grep 'Invalid JPEG compression level:')
if [[ -z "$result" ]]; then
    fail "Invalid JPEG compression level not trapped" $test_num $LINENO
fi

pass


# TEST -- check good compression value
new_test
result=$("$test_app" -s "$image_src/doctor.png" -a s 150 150 -f jpg -j 50 -d . 2>&1)

# Make sure bad value trapped
result=$(echo -e "$result" | grep 'Invalid JPEG compression level:')
if [[ -n "$result" ]]; then
    fail "Invalid JPEG compression level not trapped" $test_num $LINENO
fi

rm doctor.jpg
pass


# TEST -- check good compression value with % sign
new_test
result=$("$test_app" -s "$image_src/doctor.png" -a s 150 150 -f jpg --jpeg '42.42%' -d . 2>&1)

# Make sure good value not trapped
result=$(echo -e "$result" | grep 'Invalid JPEG compression level:')
if [[ -n "$result" ]]; then
    fail "Invalid JPEG compression level not trapped" $test_num $LINENO
fi

rm doctor.jpg
pass


# TEST -- check good compression value
new_test
result=$("$test_app" -s "$image_src/doctor.png" -a s 150 150 -f jpg -j 05 -d ./d05.jpg 2>&1)
result=$("$test_app" -s "$image_src/doctor.png" -a s 150 150 -f jpg -j 95 -d ./d95.jpg 2>&1)

# Make sure files have been written
check_file_exists d05.jpg $test_num $LINENO
check_file_exists d95.jpg $test_num $LINENO

size05=$(du -k d05.jpg | cut -f 1)
size95=$(du -k d95.jpg | cut -f 1)

if [[ ${size95} -le ${size05} ]]; then
    fail "File sizes incorrect for compression" $test_num $LINENO
fi

rm d05.jpg d95.jpg
pass

echo "ALL TESTS PASSED"
echo "DON'T FORGET TO DELETE TEST OUTPUT FILES BEFORE RE-RUNNING"
