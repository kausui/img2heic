# img2heic
img2 heic is a command line tool to convert an image file to heic image for Mac.

## System Requirements
- macOS 15.0 or higher

## Build
1. Open the terminal.
2. Clone the repositry.
3. Change the directory to the downloaded folder at step 2.
4. Enter a command "swift build".
5. img2heic binary is generated in "./.build/arm64-apple-macosx/debug/" OR "./.build/x86_64-apple-macosx/debug/" directory.

## Usage

Convert a image file
./img2heic path-to-image-file

Convert a image file with compression level
./img2heic path-to-image-file -c 0.9

compression level is between 0 to 1.0. 0 means maximum compression. 1.0 means maximum image quality. The default is 0.8. 

10 or more bits color file is converted to 10bit heif image.
Converted image file is generated in the same folder the original file is in.

## LICENSE
MIT License

Copyright (c) 2019 Kanae Usui

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
