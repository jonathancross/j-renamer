#!/opt/local/bin/perl -w
#
# J-Renamer
# Batch file renaming utility.
# Source code, issues and documentation can be found here:
#  • https://github.com/jonathancross/j-renamer
#
# See j-renamer.pl --help for more info, examples and usage.
#
# Jonathan Cross https://jonathancross.com
#
use strict;
my %renameList;
my @dirList;
my $tmp = '.tmp.';
my $script_name = $0;
# Get the name of the script
if ($script_name =~ m:([^/]*)$:) {
  $script_name = $1;
}
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
my %STATE = (
  rename_list_size    => 0,
  is_name_collision   => 0,
);

# START PROCESSING
&parseArgs();
&createRenameList();
&manageFiles();
exit;
##############################################
sub parseArgs () {
  my $i = 0;
  for my $A (@ARGV) {
    if ($A =~ /^-{1,2}in:(.+)$/) {
      # INPUT FILE LIST PATTERN
      printDebug('+ Found literal input pattern: "'.$1.'"');
      $OPTS{'input_pattern'} = "$1";
    } elsif ($A =~ /^-{1,2}ext:(lower|upper)$/) {
      # FILE EXTENSION MODIFICATION
      $OPTS{'extension_modify'} = $1;
      $OPTS{'is_extension_modify'} = 1;
    } elsif ($A =~ /^-{0,2}help|[?]$/) {
      # HELP
      printUsage('');
    } elsif ($A =~ /^-{1,2}out:(.+)$/) {
      # OUTPUT FILE NAME PATTERN
      $OPTS{'output_pattern'} = $1;
      printDebug("+ Found output pattern: \"${1}\"");
      # Check pattern syntax
      if ($OPTS{'output_pattern'} =~ /([^~#._ [:alnum:]-])/) {
        printUsage('Illegal characters in output_pattern: "'.$1.'".');
      }
      # Next bit caches non-numeric bits of the pattern
      if ($OPTS{'output_pattern'} =~ /([^#]*)(#+)([^#]*)/) {
        ($OPTS{'output_pattern_prefix'}, $OPTS{'output_pattern_digits'}, $OPTS{'output_pattern_suffix'}) = ($1, length($2), $3);
        $OPTS{'is_numeric_output_pattern'} = 1;
      } else {
        $OPTS{'is_numeric_output_pattern'} = 0;
      }
    } elsif ($A =~ /^-{1,2}start:(\d+)$/) {
      # START NUMBER
      $OPTS{'start_number'} = $1;
    } elsif ($A =~ /^-{1,2}debug$/) {
      # DEBUG
      $OPTS{'debug'} = 1;
    } elsif ($A =~ /^-{1,2}[^.\d]+[:]?.*/){
      #FAILURE
      printUsage('Unrecognized argument: "'.$A.'".');
    } else {
      #File
      if (-f $A) {
        if (-w $A) {
          $dirList[$i] = $A;
          $i++;
        } else {
          printUsage('Cannot write to file: "'.$A.'".');
        }
      } else {
        printUsage('Not a file: "'.$A.'".');
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
  @dirList = sort(@dirList); # Needed in case user inputs list with multiple file extensions
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
    printDebug("FINISEHD ARGS======================================");
  }
  #Make sure we got some files
  if (@dirList == 0) {
    if (! "$OPTS{'input_pattern'}" eq '') {
      printUsage('No files match: "'.$OPTS{'input_pattern'}.'"');
    } else {
      printUsage('You must provide file(s) to rename.');
    }
  }
}
sub printDebug {
  if ($OPTS{'debug'}) {
    print "+ DEBUG: ".$_[0]."\n";
  }
}
sub printUsage {
    if ( "$_[0]" ) {
      print "\nERROR: $_[0]\n";
    }
    print '
"J" Renamer!

USAGE: '.$script_name.' <input_pattern> <options>

OPTIONS:
  --debug                 : Must be first option if you want to see debug info.
  <input_pattern>         : Normal shell pattern. (only in *NIX / Mac terminal, Not for Windows CMD)
  --in:"<input_pattern>"  : Explicit input pattern - use quotes.
                            Patterns can be very explicit eg:
                            To select files 000_* - 045_* use this: "0[0-3][0-9]_.* 04[0-5]_.*"
  --out:<output_pattern>  : Use # (sequence number) to build an output pattern.
                            Defaults to "#_" - will prefix files with: 1_, 2_, 3_, etc..
                            Multiple "##" will force padding the number with zeros: 01_, 02_, 03_
  --start:<start_number>  : Begin sequencing output file names from an arbitrary number. Defaults to "1".
                            Can be combined with other options to just rename a particular set
                            of files while keeping original order / numbering. See ADVANCED USAGE below.
  --ext:<upper|lower>     : Make file extension upper or lower case.
                            By default will not change file extension.

EXAMPLES:
  '.$script_name.' *.*                           : Rename all files, prefix sequentially.
  '.$script_name.' --in:"*.jpg" --out:#_PIC      : 1_PIC.jpg, 2_PIC.jpg, 3_PIC.jpg ...
  '.$script_name.' *.JpG --ext:lower --start:3   : 3_.jpg, 4_.jpg, 5_.jpg ...
  '.$script_name.' *.jpg --out:"### Bob "        : "001 Bob.jpg", "002 Bob.jpg", "003 Bob.jpg" ...
  '.$script_name.' *.jpg --out:Foo_#             : Foo_1.jpg, Foo_2.jpg, F00_3.jpg ...

ADVANCED USAGE:
1. Select just a few files and number / rename only those:
   Given 11 files: 01.txt, 02.txt, 03.txt, 04.txt, 05.txt, 06.txt, 07.txt, 08.txt, 09.txt, 10.txt, 11.txt.
   Rename files 6-11, adding the word Nice like so: "03_Nice", etc, but keep in same order:
     '.$script_name.' --in:"0[6-9]* 1[01]*" --out:"#_Nice" --start:6
   Result: 06_Nice.txt, 07_Nice.txt, 08_Nice.txt, 09_Nice.txt, 10_Nice.txt, 11_Nice.txt
   Other files are unchanged.

2. Script will recognize files that have same name, but different extension and keep them grouped.
   This is common with photography where you may have both jpg and raw versions of a photo.
   Given these files: 1.jpg, 1.raw, 2.jpg, 3.jpg, 3.raw
     '.$script_name.' --in:"*.jpg *.orf" --out:"Pic_#"
   Result: Pic_1.jpg, Pic_1.raw, Pic_2.jpg, Pic_3.jpg, Pic_3.raw

TIPS:
1. The --start parameter only applies to the resulting file names, not the input names.
   The input file names are completely controlled by the input pattern so this may lead to unexpected behavior:
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
   The trick is to pad 8 and 9 with zeros before using j-renamer:
     08.jpg will be renamed to 1.jpg
     09.jpg will be renamed to 2.jpg
     10.jpg will be renamed to 3.jpg

2.  There is no "-end" parameter, the script just sequentially renames all files identified by the "-in" pattern.

3. All files are renamed according to the output pattern, therefore EXISTING FILE NAMES WILL BE DESTROYED.
   Given these files: dog.jpg, man.jpg, pizza.jpg
     '.$script_name.' --in:"*.jpg" --out:"#-Ouch"
   Result: 1-Ouch.jpg, 2-Ouch.jpg, 3-Ouch.jpg

   This is why you should rename / number all files with j-renamer BEFORE you start adding individual names one at a time.

SUPPORT:

 • https://github.com/jonathancross/j-renamer

  ';
  exit;
}

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
    if ( ! ($curFilePrefix eq $prevFilePrefix)){
      $uniqueFileNames++;
    }
    $prevFilePrefix = $curFilePrefix;
  }
  # Digits in the number of unique file names.
  my $uniqueFileNameDigits = length(int($uniqueFileNames));

  # Padding escalation... user can pad more than is necessary via multiple hash.
  if ($OPTS{'output_pattern_digits'} gt $uniqueFileNameDigits) {
    printDebug("+Escalating padding from: ${uniqueFileNameDigits} to $OPTS{'output_pattern_digits'} due to pattern.");
    $uniqueFileNameDigits = $OPTS{'output_pattern_digits'};
  }

  my $outputFileName;
  foreach my $curFileName (@dirList) {
    my ($curFilePrefix, $curFileExtension) = ($curFileName =~ /(.*)([.][^.]+)$/);
    # This allows us to keep grouping of files with same name, but different extensions.
    if ( ! ($curFilePrefix eq $prevFilePrefix)){
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

sub getOutputFileName {
  my ($inputFileName, $curNumberPadded, $fileExtension) = @_;
  my $outputFileName;
  if ( $OPTS{'is_extension_modify'} ) {
    if ($OPTS{'extension_modify'} eq 'lower') {
      $fileExtension = lc($fileExtension);
    } elsif ($OPTS{'extension_modify'} eq 'upper'){
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

sub processFileList {
  my $fileOpperation = $_[0];
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

sub processFile {
  my $inputFileName = $_[0];
  my $outputFileName = $_[1];
  my $fileOpperation = $_[2];
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

sub getPaddedNumber {
  my $curNumber = $_[0];
  my $digitsMax = $_[1];
  my $currentLen = length($curNumber);
  for (my($d) = $digitsMax - $currentLen;$d>0;$d--) {
    $curNumber = "0".$curNumber;
    #print "  Padding: 0$curNumber\n";
  }
  return $curNumber;
}

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
