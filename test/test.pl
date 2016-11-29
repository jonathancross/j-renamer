#!/opt/local/bin/perl -w
#
# Unit tests for j-renamer.pl
# Should be run as ./test.pl
#
use strict;

my $script_name = "../../j-renamer.pl"; # Path from test_data/ subdir.
my $test_data = "test_data/";
my $test_results = "../results";

runTests();

exit;

################################################################################
# Runs tests
sub runTests {
  _testDefault();
}

sub _testDefault {
  my $name = 'default';
  my $expected = 'a.txt 1.txt
b.jpg 2.jpg
b.txt 2.txt
c.txt 3.txt
d.TXT 4.TXT
';
  _runTest($name, '', $expected);
}

################################################################################
# Testing template
sub _runTest {
  my ($name, $params, $expected) = @_;
  my $results_file = "results_$name.txt";
  # Cleans up output from j-renamer.pl
  my $sedRe = '/=>/!d; s/  \([abcd].[A-z]\{3\}\).*\([0-9].[A-z]\{3\}\).*/\1 \2/g';
  printf " • Testing $name:";
  my @args = ("cd $test_data; $script_name * $params <<< n | sed '${sedRe}' > ../$results_file");
  system(@args) == 0
      or die "system @args failed: $?";
  my $result = _loadResults($results_file);
  if ($result eq $expected) {
    printf " PASS\n";
  } else {
    printf " FAIL\n";
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
__END__
