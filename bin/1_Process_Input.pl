#!/usr/bin/perl
#################################################
#       Interview Scheduler ver 0.5b            #
# The purpose is to automatically create a      #
# schedule of interviews based on certain       #
# parameters:                                   #
# - professor preferences to student            #
# - professor availabilities                    #
# - student preferences to professor            #
# - distance between interview locations        #
# Authors:					#
# Stella Hartono (srhartono@ucdavis.edu)	#
# Linda Su-Fehrer (lsu@ucdavis.edu)		#
# Ravi Dandekar (rdandekar@ucdavis.edu)		#
#################################################

##########################################
# 1_Process_Input.pl			 #
# This script Format raw input files and #
# create input files for 2_Scheduler.pl	 #
##########################################

use strict; use warnings FATAL => 'all';
use Getopt::Std;
use vars qw($opt_p $opt_s $opt_n $opt_h $opt_v $opt_a $opt_b);
getopts("p:s:n:abhv:");

BEGIN {
	my $dir = `pwd` . "/bin/";
	$dir =~ s/\n//;
	$dir =~ s/bin\/bin/bin/;
	push (@INC, $dir);
}

use scheduler;

schedulerFormat::print_usage() and die "No input detected!\n\n" unless defined($opt_p) and defined($opt_s) and defined($opt_n);
schedulerFormat::print_usage() and die "\n" if ($opt_h);
schedulerFormat::check_sanity($opt_p, $opt_s, $opt_n);
my $excelProf = defined($opt_a) ? 1 : 0;
my $excelStud = defined($opt_b) ? 1 : 0;
die "Fatal Error: Professor schedule file is detected as excel format but option -a is not defined\n" if $excelProf == 0 and $opt_p =~ /.xls$/i;
die "Fatal Error: Student preference file is detected as excel format but option -b is not defined\n" if $excelStud == 0 and $opt_s =~ /.xls$/i;
die "Fatal Error: Professor schedule file is detected as non-excel format but option -a is defined\n" if $excelProf == 1 and $opt_p !~ /.xls$/i;
die "Fatal Error: Student preference file is detected as non-excel format but option -b is defined\n" if $excelStud == 1 and $opt_s !~ /.xls$/i;

my ($professorFile, $studentFile, $projectName) = ($opt_p, $opt_s, $opt_n);
my ($main_dir, $result_dir) = schedulerFormat::define_directory($projectName);

print "1. Processing professor schedule raw file $professorFile and creating data and schedule table...\n";
schedulerFormat::processProfessorTable($professorFile, $result_dir, $main_dir, $excelProf);

print "2. Processing student schedule raw file $studentFile and creating data and preference table...\n";
schedulerFormat::processStudentTable($studentFile, $result_dir, $excelStud);

print "3. Creating table of professors that want to meet with certain students...\n";
schedulerFormat::processProfessorDemand("$result_dir\/student_preference_final.txt", $result_dir);

print "Done!\n";



if ($opt_v == 1) {
	print "\nResults\n";
	print "Note: Resulting files are all .TSV format (Tab Separated Values)\n\n";
	my @result = (
	"$result_dir\/professor_table_final.txt",
	"$result_dir\/professor_schedule_final.txt",
	"$result_dir\/student_table_final.txt",
	"$result_dir\/student_preference_final.txt",
	"$result_dir\/professor_preference_final.txt",
	"$result_dir\/professor_without_schedule.txt"
	);
	
	for (my $i = 0; $i < @result; $i++) {
		print "$i. $result[$i]:\n";
		system("cat $result[$i]");
		print "\n";
	}
}
__END__
# Default
else {
	my ($result_dir) = $0 =~ /^(.+)\/bin\/initial_format.pl/i;
	($result_dir) = "../Data" if not defined($result_dir);
	($professorFile, $studentFile) = ("$result_dir\/professor_schedule_raw.tsv", "$result_dir\/student_preference_raw.tsv");
	print "Processing:\n1. Professor raw file $professorFile\n2. Student raw file $studentFile\n";
	# Get the data directory
	
	schedulerFormat::prof_list_conversion($professorFile);
	schedulerFormat::stud_list_conversion($studentFile);
	schedulerFormat::stud_pref_conversion("$result_dir\/student_table_final.txt", "$result_dir\/professor_table_final.txt", $studentFile);
	print "Done!\n";
}

