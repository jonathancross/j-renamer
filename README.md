# J-Renamer
Batch file renaming utility.

J-Renamer is written in standard Perl with no additional modules / packages required.
It should just "work" on Mac and Linux/Unix systems and probably Cygwin.

See `j-renamer.pl --help` from commandline for usage, examples and tips.


### Usage
    j-renamer.pl <input_pattern> <options>


### Options:
    --debug                 : Must be first option if you want to see debug info.
    <input_pattern>         : Normal shell pattern. (only in *NIX / Mac terminal, Not for Windows CMD)
    --in:"<input_pattern>"  : Explicit input pattern - use quotes.
                              Patterns can be very explicit eg:
                              To select files 000_* - 045_* use this: "0[0-3][0-9]_.* 04[0-5]_.*"
    --out:<output_pattern>  : Use # (sequence number) to build an output pattern.
                              Defaults to "#_" - will prefix files with: 1_, 2_, 3_, etc..
                              Multiple "##" will force padding the number with zeros: 01_, 02_, 03_
    --start:<start_number>  : Begin sequencing output file names from an arbitrary number. Defaults to "1".
                              Can be combined with other options to just rename a particular set of files
                              while keeping original order / numbering.  See "Advanced usage" below.
    --ext:<upper|lower>     : Make file extension upper or lower case.
                              By default will not change file extension.


### Examples:
    j-renamer.pl *.*                         : Rename all files, prefix sequentially.
    j-renamer.pl --in:"*.jpg" --out:#_PIC    : 1_PIC.jpg, 2_PIC.jpg, 3_PIC.jpg ...
    j-renamer.pl *.JpG --ext:lower --start:3 : 3_.jpg, 4_.jpg, 5_.jpg ...
    j-renamer.pl *.jpg --out:"### Bob"       : "001 Bob.jpg", "002 Bob.jpg", "003 Bob.jpg" ...
    j-renamer.pl *.jpg --out:Foo_#           : Foo_1.jpg, Foo_2.jpg, F00_3.jpg ...


### Advanced usage:
1. Select just a few files and number / rename only those:

   Given 11 files: 01.txt, 02.txt, 03.txt, 04.txt, 05.txt, 06.txt, 07.txt, 08.txt, 09.txt, 10.txt, 11.txt.

   Rename files 6-11, adding the word Nice like so: "03_Nice", etc, but keep in same order:

        j-renamer.pl --in:"0[6-9]* 1[01]*" --out:"#_Nice" --start:6
   Result: 06_Nice.txt, 07_Nice.txt, 08_Nice.txt, 09_Nice.txt, 10_Nice.txt, 11_Nice.txt

   Other files are unchanged.

2. Script will recognize files that have same name, but different extension and keep them grouped.<br>
   This is common with photography where you may have both jpg and raw versions of a photo.

   Given these files: 1.jpg, 1.raw, 2.jpg, 3.jpg, 3.raw

        j-renamer.pl --in:"*.jpg *.orf" --out:"Pic_#"

   Result: Pic_1.jpg, Pic_1.raw, Pic_2.jpg, Pic_3.jpg, Pic_3.raw


### Additional tips:
1. The `-start` option only applies to the resulting file names, not the input names.<br>
   The input file names are completely controlled by the input pattern so this may lead to unexpected behavior:

   Given these files: 1.jpg, 2.jpg, 3.jpg

        j-renamer.pl --in:"*.jpg" --out:"#" --start:4

   Result: 4.jpg, 5.jpg, 6.jpg

   Also note that the file order is always alphabetical, so:

   Given these files: 8.jpg, 9.jpg, 10.jpg

        j-renamer.pl --in:"*.jpg" --out:"#"

   The numbering will be messed up:

        10.jpg will be renamed to 1.jpg
         8.jpg will be renamed to 2.jpg
         9.jpg will be renamed to 3.jpg

   The trick is to manually pad with zeros before using j-renamer:

        08.jpg will be renamed to 1.jpg
        09.jpg will be renamed to 2.jpg
        10.jpg will be renamed to 3.jpg

2.  There is no `-end` parameter, the script just sequentially renames all files identified by the `-in` pattern.

3. All files are renamed according to the output pattern, therefore **existing file names will be destroyed**.

   Given these files: dog.jpg, man.jpg, pizza.jpg

        j-renamer.pl --in:"*.jpg" --out:"#-Ouch"

   Result: 1-Ouch.jpg, 2-Ouch.jpg, 3-Ouch.jpg

   This is why you should rename / number all files with j-renamer **before** you start adding individual names one at a time.

### History
This script was first developed on Windows XP using archaic `cmd` shell commands.  It was later re-written in perl with many new features and bug fixes.

The original version can be found here:
https://sourceforge.net/projects/j-renamer/
