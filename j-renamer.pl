#!/opt/local/bin/perl -w
#
# J-Renamer
# Batch file renaming utility.
# Source code, issues and documentation can be found here:
#  • https://github.com/jonathancross/j-renamer
#
# See j-renamer.pl --help for more info, examples and usage.
#
# TODO:
#  • Add support for date.
#  • Add option to keep existing file names.
#
# Jonathan Cross https://jonathancross.com
#
use strict;
my %renameList;
my @dirList;
my $tmp = '.tmp.';
my $script_name = $0;

# Get the name of the script:
if ($script_name =~ m:([^/]*)$:) {
  $script_name = $1;
}

# Program options and defaults:
my %OPTS = (
  input_pattern         => '',
  output_pattern        => '#_',
  output_pattern_prefix => '',
  output_pattern_suffix => '',
  output_pattern_digits => 1,
  is_numeric_output_pattern => 1,
  start_number          => 1,
  extension_modify      => '',
  is_extension_modify   => 0,
  debug                 => 0,
);

# Global state properties:
my %STATE = (
  rename_list_size    => 0,
  is_name_collision   => 0,
);

# START PROCESSING
# TODO: Wrap these in a single function and remove & (not needed in perl5 +)
&parseArgs();
&createRenameList();
&manageFiles();
exit;

################################################################################
#   parseArgs()
#   Parses commandline arguments and overrides defaults in %OPTS.
#   TODO: Pass in @ARGV
sub parseArgs {
  my $i = 0;
  for my $arg (@ARGV) {
    if ($arg =~ /^-{1,2}in:(.+)$/) {
      # Input file list pattern
      printDebug('+ Found literal input pattern: "'.$1.'"');
      $OPTS{'input_pattern'} = "$1";
    } elsif ($arg =~ /^-{1,2}ext:(lower|upper)$/) {
      # File extension modification
      $OPTS{'extension_modify'} = $1;
      $OPTS{'is_extension_modify'} = 1;
    } elsif ($arg =~ /^-{0,2}help|[?]$/) {
      # Help
      printUsage('');
    } elsif ($arg =~ /^-{1,2}out:(.+)$/) {
      # Output file name pattern
      $OPTS{'output_pattern'} = $1;
      printDebug("+ Found output pattern: \"${1}\"");
      # Check pattern syntax
      if ($OPTS{'output_pattern'} =~ /([^~#._ [:alnum:]-])/) {
        printUsage('Illegal characters in output_pattern: "'.$1.'".');
      }
      # Cache non-numeric parts of the pattern:
      if ($OPTS{'output_pattern'} =~ /([^#]*)(#+)([^#]*)/) {
        ($OPTS{'output_pattern_prefix'}, $OPTS{'output_pattern_digits'}, $OPTS{'output_pattern_suffix'}) = ($1, length($2), $3);
        $OPTS{'is_numeric_output_pattern'} = 1;
      } else {
        $OPTS{'is_numeric_output_pattern'} = 0;
      }
    } elsif ($arg =~ /^-{1,2}start:(\d+)$/) {
      # Number to start counting from
      $OPTS{'start_number'} = $1;
    } elsif ($arg =~ /^-{1,2}debug$/) {
      # Debug
      $OPTS{'debug'} = 1;
    } elsif ($arg =~ /^-{1,2}[^.\d]+[:]?.*/) {
      # Failure
      printUsage('Unrecognized argument: "'.$arg.'".');
    } else {
      # File
      if (-f $arg) {
        if (-w $arg) {
          $dirList[$i] = $arg;
          $i++;
        } else {
          printUsage('Cannot write to file: "'.$arg.'".');
        }
      } else {
        printUsage('Not a file: "'.$arg.'".');
      }
    }
  }
  if ($OPTS{'input_pattern'}) {
    printDebug('+ Using input pattern for dirList: "'.$OPTS{'input_pattern'}.'"');
    @dirList = glob($OPTS{'input_pattern'});
  } elsif (@dirList gt 0) {
    printDebug("Shell is providing dirList.");
  } else {
    printUsage('No input files found.');
  }
  $STATE{'rename_list_size'} = @dirList;
  # Sort file list in case user inputs list with multiple file extensions:
  @dirList = sort(@dirList);
  if ($OPTS{'debug'}) {
    printDebug("DIRLIST:");
    for (my $k = 0;$k<@dirList;$k++) {
      printDebug("   - dirList[$k] = $dirList[$k]");
    }
    printDebug("OPTIONS:");
    foreach my $k (sort keys %OPTS) {
      printDebug("   - $k = $OPTS{$k}");
    }
    printDebug("STATE:");
    foreach my $k (sort keys %STATE) {
      printDebug("   - $k = $STATE{$k}");
    }
    printDebug("FINISHED ARGS======================================");
  }
  # Make sure we got some files:
  if (@dirList == 0) {
    if (! "$OPTS{'input_pattern'}" eq '') {
      printUsage('No files match: "'.$OPTS{'input_pattern'}.'"');
    } else {
      printUsage('You must provide file(s) to rename.');
    }
  }
}

################################################################################
#   printDebug($message)
#   Prints $message if debug mode is enabled.
sub printDebug {
  if ($OPTS{'debug'}) {
    print "+ DEBUG: ".$_[0]."\n";
  }
}

################################################################################
#   printUsage($error)
#   Prints information on how to use this script and an optional $error.
sub printUsage {
    print "J Renamer\n";

    if ("$_[0]") {
      print "\nERROR: $_[0]\n";
    }
    print '

USAGE: '.$script_name.' <input_pattern> <options>

OPTIONS:
  --debug             : Must be first option if you want to see debug info.
  <input_pattern>     : Shell input pattern. (only *NIX / Mac, Not Windows)
  --in:"<pattern>"    : Explicit input pattern - use quotes.
                        Advanced globing patterns are supported:
                        Eg: To select files 000_* - 045_* use this pattern:
                          "0[0-3][0-9]_.* 04[0-5]_.*"
  --out:<pattern>     : Use # (sequence number) to build an output pattern.
                        Defaults to "#_" which will prefix files with:
                            1_,  2_,  3_
                        Multiple "##" will force padding with zeros:
                           01_, 02_, 03_ ...
  --start:<number>    : Begin sequencing output file names from start number.
                        Defaults to "1".
                        Can be combined with other options to only rename a
                        particular subset of files while keeping original order
                        and numbering. See ADVANCED USAGE below.
  --ext:<upper|lower> : Make file extension upper or lower case.
                        By default will not change file extension.

EXAMPLES:
  '.$script_name.' *.*                     : Prefix all files sequentially.
  '.$script_name.' --in:"*.jpg" --out:#_Me : 1_Me.jpg, 2_Me.jpg, 3_Me.jpg ...
  '.$script_name.' *.JPG --ext:lower       : 3_.jpg, 4_.jpg, 5_.jpg ...
  '.$script_name.' *.jpg --start:3         : 3_.jpg, 4_.jpg, 5_.jpg ...
  '.$script_name.' *.c --out:"## X"        : "01 X.c", "02 X.c", "03 X.c" ...
  '.$script_name.' *.jpg --out:Foo_#       : Foo_1.jpg, Foo_2.jpg, F00_3.jpg ...

ADVANCED USAGE:
1. Select just a few files and number / rename only those:
   Given 11 files: 01.txt ... 11.txt:
   Rename files number 7 - 11, adding the word "Nice" while maintaining order:
     '.$script_name.' --in:"0[7-9]*.txt 1[01]*.txt" --out:"##_Nice" --start:7
   Result: 07_Nice.txt, 08_Nice.txt, 09_Nice.txt, 10_Nice.txt, 11_Nice.txt
   Files 1-6 are unchanged.

2. Will keep grouping of files that have same name, but different extension.
   Example with photography where you have both jpg and raw versions of a photo.
   Given these files: 1.jpg, 1.raw, 2.jpg, 3.jpg, 3.raw
     '.$script_name.' --in:"*.jpg *.raw" --out:"Pic_#"
     (Note that 2.jpg does not have a .raw version, but others do)
   Result: Pic_1.jpg, Pic_1.raw, Pic_2.jpg, Pic_3.jpg, Pic_3.raw

TIPS:
1. The --start option refers to the output file names, not the input names.
   The input file names are completely controlled by the input pattern so this
   may lead to unexpected behavior:
   Given these files: 1.jpg, 2.jpg, 3.jpg
     '.$script_name.' --in:"*.jpg" --out:"#" --start:4
   Result: 4.jpg, 5.jpg, 6.jpg

   Also note that the file order is always alphabetical, so:
   Given these files: 8.jpg, 9.jpg, 10.jpg
     '.$script_name.' --in:"*.jpg" --out:"#"
   The numbering will be messed up:
     10.jpg will be renamed to 1.jpg
      8.jpg will be renamed to 2.jpg
      9.jpg will be renamed to 3.jpg
   Solution is to pad 8 and 9 with zeros first so the order is preserved:
     '.$script_name.' --in:"[8-9].jpg" --out:"##" --start:8
   Result:
      8.jpg will be renamed to 08.jpg
      9.jpg will be renamed to 09.jpg
   (you can of course rename 8.jpg and 9.jpg by hand to get the same result)

   Then, continue with the original rename:
     '.$script_name.' --in:"*.jpg" --out:"#"
     08.jpg will be renamed to 1.jpg
     09.jpg will be renamed to 2.jpg
     10.jpg will be renamed to 3.jpg

2. There is no "--end" parameter, the script just sequentially renames all files
   identified by the "--in" pattern.

3. All matched files are renamed according to the output pattern, therefore
   EXISTING FILE NAMES WILL BE DESTROYED.
   Given these files: dog.jpg, man.jpg, pizza.jpg
     '.$script_name.' --in:"*.jpg" --out:"#-Ouch"
   Result: 1-Ouch.jpg, 2-Ouch.jpg, 3-Ouch.jpg

   This is why you should rename / number all files with j-renamer BEFORE you
   start adding individual names manually.

SUPPORT:

 • https://github.com/jonathancross/j-renamer

  ';
  exit;
}

################################################################################
#   createRenameList()
#   Fills %renameList such that $renameList{$oldFile} = $newFile
#   Will also set $STATE{'is_name_collision'} if needed.
#   TODO: local vars
sub createRenameList {
  my $curNumber = ($OPTS{'start_number'} - 1); # Hmmm... better way to do this?
  my $curNumberPadded = $OPTS{'start_number'};

  # Used to prevent double-counting of files which are identical, except for their extension.
  my $uniqueFileNames = 0;

  # Used to handle files with different extensions, but same name
  my $prevFilePrefix = '';
  # Make sure that $uniqueFileNameDigits doesn't double-count files with same name and different extensions.
  foreach my $curFileName (@dirList) {
    my ($curFilePrefix, $curFileExtension) = ($curFileName =~ /(.*)([.][^.]+)$/);
    # This allows us to keep grouping of files with same name, but different extensions
    if ( ! ($curFilePrefix eq $prevFilePrefix)) {
      $uniqueFileNames++;
    }
    $prevFilePrefix = $curFilePrefix;
  }
  # Digits in the number of unique file names.
  my $uniqueFileNameDigits = length(int($uniqueFileNames));

  # Padding override... user can pad more than is necessary via multiple hash symbols.
  if ($OPTS{'output_pattern_digits'} gt $uniqueFileNameDigits) {
    printDebug("+Overriding padding from: ${uniqueFileNameDigits} to $OPTS{'output_pattern_digits'} due to pattern.");
    $uniqueFileNameDigits = $OPTS{'output_pattern_digits'};
  }

  my $outputFileName;
  foreach my $curFileName (@dirList) {
    my ($curFilePrefix, $curFileExtension) = ($curFileName =~ /(.*)([.][^.]+)$/);
    # This allows us to keep grouping of files with same name, but different extensions.
    if ( ! ($curFilePrefix eq $prevFilePrefix)) {
      $curNumber++;
    }
    $curNumberPadded = getPaddedNumber($curNumber, $uniqueFileNameDigits);
    $outputFileName = getOutputFileName($curFileName, $curNumberPadded, $curFileExtension);
    if ($STATE{'is_name_collision'} ne 1 && -f $outputFileName) {
      printDebug("name_collision: $outputFileName");
      $STATE{'is_name_collision'} = 1;
    }
    $renameList{$curFileName} = $outputFileName;
    $prevFilePrefix = $curFilePrefix;
  }
}

################################################################################
#   getOutputFileName($inputFileName, $curNumberPadded, $fileExtension)
#   Given an inputFileName, returns the outputFileName.
#   @returns $outputFileName
sub getOutputFileName {
  my ($inputFileName, $curNumberPadded, $fileExtension) = @_;
  my $outputFileName;
  if ( $OPTS{'is_extension_modify'} ) {
    if ($OPTS{'extension_modify'} eq 'lower') {
      $fileExtension = lc($fileExtension);
    } elsif ($OPTS{'extension_modify'} eq 'upper') {
      $fileExtension = uc($fileExtension);
    }
  }
  if ($OPTS{'is_numeric_output_pattern'}) {
    $outputFileName = "$OPTS{'output_pattern_prefix'}${curNumberPadded}$OPTS{'output_pattern_suffix'}${fileExtension}";
  } else {
    $outputFileName = "${curNumberPadded}_".$OPTS{'output_pattern'}."${fileExtension}";
  }
  return $outputFileName;
}

################################################################################
#   manageFiles()
#   Manages preview and renaming of the whole list of files and prompting user.
sub manageFiles {
  my $doRename = '';
  if ($STATE{'rename_list_size'} == 0) {
    printUsage("No files to rename.");
  }
  processFileList('preview');
  until ($doRename =~ /^y|^n/) {
    $doRename = &prompt("\n\nRENAME ABOVE FILES? (y|n) ", "n");
  }
  if ($doRename eq 'y') {
    if ($STATE{'is_name_collision'}) {
      #CRUDE???
      printDebug('Handling collisions: ');
      processFileList('collision_handeling');
    }
    processFileList('rename');
  } else {
    print "
  + RENAME CANCELED!
    No files were changed.\n";
  }
  print "\n\n[ DONE ]\n";
}

################################################################################
#   processFileList($fileOpperation)
#   $fileOpperation must be one of (preview|rename|collision_handeling)
#   Handles outer rename loop and debug info.
sub processFileList {
  my $fileOpperation = $_[0];
  # TODO: Ensure $fileOpperation =~ m:^(preview|rename|collision_handeling)$:
  my $outputFileName;
  if ($fileOpperation ne 'collision_handeling') {
    print "\n".uc($fileOpperation)." $STATE{'rename_list_size'} FILES:\n";
  } else {
    print "\nCollision protection enabled...\n";
  }
  foreach my $inputFileName (sort keys %renameList) {
    $outputFileName = $renameList{$inputFileName};
    processFile($inputFileName, $outputFileName, $fileOpperation);
  }
}

################################################################################
#   processFile($inputFileName, $outputFileName, $fileOpperation)
#   Handles rename and / or preview of a single file.
sub processFile {
  my ($inputFileName, $outputFileName, $fileOpperation) = @_;

  if ($fileOpperation eq 'rename') {
    if ($STATE{'is_name_collision'}) {
      #use buffered file
      $inputFileName = $tmp.$outputFileName;
    }
    print "\n  Renaming : ${inputFileName}\t=>\t${outputFileName}";
    if (-f $outputFileName) {
      print ' [ERROR FILE ALREADY EXISTS]'
    } elsif ( ! rename($inputFileName, $outputFileName)) {
      print ' [ERROR]';
      #exit 1;
    }
  } elsif ($fileOpperation eq 'collision_handeling') {
    #prefix
    $outputFileName = $tmp.$outputFileName;
    if (! -f $outputFileName) {
      rename($inputFileName, $outputFileName);
    } else {
      print "\n[ERROR: \"${outputFileName}\" Already exists! ]";
    }
  } else {
    print "\n  ${inputFileName}\t=>\t${outputFileName}";
  }
}

################################################################################
#   getPaddedNumber($curNumber, $digitsMax)
#   Given a number $curNumber, will pad as needed up to $digitsMax
#   @returns padded number.
sub getPaddedNumber {
  my ($curNumber, $digitsMax) = @_;
  my $currentLen = length($curNumber);
  for (my $d = $digitsMax - $currentLen; $d > 0; $d--) {
    $curNumber = "0".$curNumber;
    #print "  Padding: 0$curNumber\n";
  }
  return $curNumber;
}

################################################################################
#   prompt($promptString, $defaultValue)
#   Prompts user for input and supports an optional default $defaultValue.
#   @returns the value selected by user or default.
sub prompt {
   my($promptString, $defaultValue) = @_;
   if ($defaultValue) {
     print $promptString, "[", $defaultValue, "]: ";
   } else {
     print $promptString, ": ";
   }
   $| = 1;               # force a flush after our print
   $_ = <STDIN>;         # get the input from STDIN (presumably the keyboard)
   chomp;
   if ("$defaultValue") {
     return $_ ? $_ : $defaultValue; # return $_ if it has a value
   } else {
     return $_;
   }
}

__END__
