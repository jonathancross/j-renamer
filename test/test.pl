#!/opt/local/bin/perl -w
#
# Unit tests for j-renamer.pl
# Should be run as ./test.pl
#
use strict;

my $script_name = "../../j-renamer.pl"; # Path from test_data/ subdir.
my $test_data = "test_data/";
my $test_results = "../results";

_runTests();
_tearDown();

exit;

################################################################################
# Runs tests
sub _runTests {
  printf "Running unit tests:\n";
  _testDefault();
  _testUpper();
  _testLower();
  _testPatternFoo();
  _testInAndStart();
  _testForcedPaddingViaPattern();
  _testForcedPaddingViaStart();
}

sub _testDefault {
  _runTest('',
           'a.txt 1.txt
b.jpg 2.jpg
b.txt 2.txt
c.txt 3.txt
d.TXT 4.TXT
');
}

sub _testUpper {
  _runTest('--ext:upper',
           'a.txt 1.TXT
b.jpg 2.JPG
b.txt 2.TXT
c.txt 3.TXT
d.TXT 4.TXT
');
}

sub _testLower {
  _runTest('--ext:lower',
           'a.txt 1.txt
b.jpg 2.jpg
b.txt 2.txt
c.txt 3.txt
d.TXT 4.txt
');
}

sub _testPatternFoo {
  _runTest('--out:Foo_#',
           'a.txt Foo_1.txt
b.jpg Foo_2.jpg
b.txt Foo_2.txt
c.txt Foo_3.txt
d.TXT Foo_4.TXT
');
}

sub _testInAndStart {
  # Tests if complex --in pattern works and simple --start example.
  _runTest('--in:"*.{txt,TXT}" --start:6',
            'a.txt 6.txt
b.txt 7.txt
c.txt 8.txt
d.TXT 9.TXT
');
}

sub _testForcedPaddingViaPattern {
  _runTest('--out:###',
           'a.txt 001.txt
b.jpg 002.jpg
b.txt 002.txt
c.txt 003.txt
d.TXT 004.TXT
');
}

sub _testForcedPaddingViaStart {
  # Tests if more complex start correctly triggers forced padding.
  _runTest('--start:7',
           'a.txt 07.txt
b.jpg 08.jpg
b.txt 08.txt
c.txt 09.txt
d.TXT 10.TXT
');
}

################################################################################
# Runs a given unit test and checks the result.
# @param $params   Parameters to send to j-renamer
# @param $expected Expected result of rename.
sub _runTest {
  my ($params, $expected) = @_;
  my ($name) = ((caller(1))[3] =~ /main::_test([A-z]+)$/);
  my $results_file = "results_$name.txt";
  # Cleans up output from j-renamer.pl
  my $sedRe = '/=>/!d; s/  \([abcd].[A-z]\{3\}\).*=>[^A-z0-9 _-]*\([A-z0-9 _-]*\.[A-z]\{3\}\).*/\1 \2/g';
  printf " • Testing $name:";
  #                                               Use tee here for debug ---+
  #                                                                         |
  #                                                                         V
  my @args = ("cd $test_data; $script_name * $params <<< n | sed '${sedRe}' > ../$results_file");
  system(@args) == 0
      or die "system @args failed: $?";
  my $result = _loadResults($results_file);
  if ($result eq $expected) {
    printf " PASS\n";
  } else {
    printf " FAILED!
    Try running this:
    cd $test_data; $script_name * $params <<< n | sed '${sedRe}'; echo 'Here were actual results:'; cat ../$results_file
    ";
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
