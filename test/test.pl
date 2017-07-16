#!/opt/local/bin/perl
#
# Unit tests for j-renamer.pl
# Should be run as ./test.pl
#
use strict;
use warnings;

my $script_name = "../../j-renamer.pl"; # Path from test_data/ subdir.
my $test_data = "test_data/";
my $test_results = "../results";

my %TEST_DATA = _getTestData();

_runTests();
_tearDown();

exit;


################################################################################
# Runs tests
sub _runTests {
  printf "Running unit tests:\n";
  foreach my $testName (keys %TEST_DATA) {
    _runTest($testName);
  }
}

sub _getTestData {
  # TODO: Put this in a text file:
  return (
  Default => ['',
'a.txt 1.txt
b.jpg 2.jpg
b.txt 2.txt
c.txt 3.txt
d.TXT 4.TXT
'],
  Upper => ['--ext:upper',
'a.txt 1.TXT
b.jpg 2.JPG
b.txt 2.TXT
c.txt 3.TXT
d.TXT 4.TXT
'],
  Lower => ['--ext:lower',
'a.txt 1.txt
b.jpg 2.jpg
b.txt 2.txt
c.txt 3.txt
d.TXT 4.txt
'],
  PatternFoo => ['--out:Foo_#',
'a.txt Foo_1.txt
b.jpg Foo_2.jpg
b.txt Foo_2.txt
c.txt Foo_3.txt
d.TXT Foo_4.TXT
'],
  InAndStart => ['--in:"*.{txt,TXT}" --start:6',
 'a.txt 6.txt
b.txt 7.txt
c.txt 8.txt
d.TXT 9.TXT
'],
  ForcedPaddingViaPattern => ['--out:###',
'a.txt 001.txt
b.jpg 002.jpg
b.txt 002.txt
c.txt 003.txt
d.TXT 004.TXT
'],
  ForcedPaddingViaStart => ['--start:7',
'a.txt 07.txt
b.jpg 08.jpg
b.txt 08.txt
c.txt 09.txt
d.TXT 10.TXT
']
);
}

################################################################################
# Runs a given unit test and checks the result.
# @param $params   Parameters to send to j-renamer
# @param $expected Expected result of rename.
sub _runTest {
  my ($name) = @_;
  my ($params, $expected) = ($TEST_DATA{$name}[0], $TEST_DATA{$name}[1]);

  my $results_file = "results_$name.txt";
  # Cleans up output from j-renamer.pl
  my $sedRe = '/=>/!d; s/  \([abcd].[A-Za-z]\{3\}\).*=>[^A-Za-z0-9 _-]*\([A-Za-z0-9 _-]*\.[A-Za-z]\{3\}\).*/\1 \2/g';
  printf " • Testing $name:";
  #                                                   Use tee here for debug ---+
  #                                                                             |
  #                                                                             V
  my @args = ("cd $test_data; perl $script_name --dry-run * $params | sed -e '${sedRe}' > ../$results_file");
  system(@args) == 0
      or die "system @args failed: $?";
  my $result = _loadResults($results_file);
  if ($result eq $expected) {
    printf " PASS\n";
  } else {
    printf " FAILED!
------------------------------------------------------
Expected results:
$expected
------------------------------------------------------
Actual results:
$result
------------------------------------------------------
Test command:
  cd $test_data; $script_name --dry-run * $params | sed '${sedRe}';cd ..;
------------------------------------------------------";
    exit 1;
  }
}

sub _loadResults {
  my ($filename) = @_;
  my $results;
  open(my $fh, '<', $filename) or die "cannot open file $filename";
  {
      local $/;
      $results = <$fh>;
  }
  close($fh);
  return $results;
}

sub _tearDown {
  # Delete all the test result files.
  my @args = ("rm results_*.txt");
  system(@args) == 0
      or die "system @args failed: $?";
}
__END__
